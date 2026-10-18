# What building a real payload teaches you

Everything below was learned the hard way while bringing a payload up on real
hardware (PS4 9.00 / GoldHEN 2.4, and 13.52). Each entry is a rule, the reason
it exists, and how to check for it. The single biggest lesson is first,
because it wastes the most time: **a payload that never runs leaves no trace.**

## 1. Linkage is the silent killer

A payload runs in a *spawned* process, under a loader that resolves every
import and kills the process on the first one it cannot resolve, with no log
line. If you link the wrong world, your payload dies before `main()` and looks
exactly like "the loader is broken".

There are two worlds:

| World | Libraries | Use it for |
|---|---|---|
| **daemon-world** | `libkernel_web.sprx`, `libSceLibcInternal.sprx`, `libSceNet.sprx` (+ `libSceSystemService.sprx` for foreground detection) | standalone ELF payloads |
| **app-world** | `libkernel.so` and the Sony app libraries (`orbis/Net.h` and friends) | PKG apps and PRX plugins, not spawned payloads |

A daemon-world payload's `NEEDED` set is exactly those `.sprx` names. An
app-world binary drags in `libkernel.so`, whose symbols have no provider in a
bare spawned process, so it is killed instantly.

Check it:

```sh
llvm-readelf -d build/payload.elf | grep NEEDED
# good: libkernel_web.sprx, libSceLibcInternal.sprx, libSceNet.sprx
# bad:  libkernel.so
```

`make check` in this repo enforces it.

Ruled out as the cause of instant death (do not chase these): PIE vs EXEC,
ELF vs SELF, binary size, hash style, relocation families, segment
permissions. It is the import set.

## 2. Build the SDK from git, not the release ZIP

The SDK's CRT gates startup on a hard-coded per-firmware table in
`crt/patch.c`. `__patch_init()` returns an error for any firmware not listed,
and `_start()` then calls `payload_terminate()` before `main()` ever runs:

```
crt/patch.c:   default: klog_printf("Unsupported firmware %x\n", fw);
crt/crt.c:     if((err = payload_init())) return payload_terminate(err);
```

A released SDK predates newer firmware, so a payload built against the ZIP
dies silently on those consoles. A firmware table shipped in a *release* had
13.50 but not 13.52; the 13.52 offsets only ever landed on the git branch.

Fix: build the SDK from source (`scripts/setup_sdk.sh`), and check
`crt/patch.c` lists your firmware before you build. Check the SDK *source*,
not a byte-scan of the linked ELF: a 4-byte offset pattern occurs by chance in
a 2 MB binary, so scanning proves nothing.

## 3. Know your loader and its one-shot rule

There are three ways to get bytes into the console, and they behave very
differently:

| Loader | Port | Behavior |
|---|---|---|
| GoldHEN settings-page payloader | 9090 | Accepts bytes, prints "payload launched successfully", then its loader thread may segfault (`signal 11 ... thread GoldHENLoader`, fault address 0). ELF support needs GoldHEN >= v2.4b18.5. |
| GoldHEN BinLoader server | 9020 | **One-shot per arm.** Any port *check* (even an empty connect) burns the arm. Fire blind. |
| elfldr (ps4-payload-dev) | 9021 | Serves until reboot. Best harness for third-party ELF. |

The rule that matters: **never port-check 9020 or 9090 before sending.** The
first connection must already carry the payload. Use elfldr (9021) for a
normal edit/build/deploy loop.

## 4. `log.txt` absent always means "never executed"

The observation channels are:

| Channel | Address | Use |
|---|---|---|
| Kernel log (klog) | TCP `:3232` | loader events, faults, `printf()` from your payload |
| FTP | `:2121` (anonymous) | move files on and off |
| BinLoader | `:9020` | inject (one-shot) |
| elfldr | `:9021` | inject + iterate |

`printf()` in a daemon-world payload is wired to klog. If a file your payload
writes is absent, the payload never ran, it did not "crash later". klog is a
live firehose: capture across the send window, not after.

## 5. Never FTP-upload a PRX or SELF

The console-side write path deterministically converts SELF containers to raw
ELF. A PRX uploaded over FTP lands with a different size and hash (observed:
a 1,476,032-byte PRX arrived as a 1,719,072-byte ELF). Random bytes and PKGs
round-trip perfectly. Deliver plugins via PKG install only.

## 6. mbedTLS 3.x: TLS 1.3 init fails on-console

Every TLS handshake died instantly with return `-1` after DNS and TCP already
succeeded. The mbedTLS debug trace told the real story:

```
psa_crypto_init() returned -148 (-0x0094, INSUFFICIENT_ENTROPY)
```

mbedTLS 3.x routes TLS 1.3 through the PSA crypto subsystem, whose init fails
on PS4 even though `/dev/urandom` reads fine. Fix: cap the version at TLS 1.2.

```c
mbedtls_ssl_conf_max_tls_version(&conf, MBEDTLS_SSL_VERSION_TLS1_2);
```

Lesson underneath the lesson: wire mbedTLS's debug layer
(`mbedtls_debug_set_threshold` + `mbedtls_ssl_conf_dbg`) into klog *before*
guessing at handshake bugs.

## 7. Dialogs: init once, and per dialog

Common-dialog state is process-global and easy to get wrong:

- `sceCommonDialogInitialize()` must run before any external dialog module
  loads.
- `sceMsgDialogInitialize` is required; without it every open fails into a
  black loop. Init and terminate **per dialog** (the Apollo PS4 pattern).
- IME still refuses on-console after every known workaround. Codes seen:
  `0x80BC0008` with `userId=0`, `0x80BC0010` with the real foreground user.
  Pre-seed config instead of prompting.

Init order that works: `sceSystemService` -> `sceUserService` ->
`sceCommonDialogInitialize()` -> pad (`scePadInit()`) -> external modules.

## 8. A flat `.bin` has no dynamic linker

Two SDK families exist and they are not interchangeable:

- **ELF** (ps4-payload-dev SDK): dynamically linked, relocations applied by
  the loader. This is what elfldr and BinLoader expect.
- **Flat `.bin`** (Scene-Collective libPS4 style): loaded at an arbitrary
  address with no relocations during load. Static pointer tables (vtables,
  function-pointer tables) point at link-time addresses and break. If you must
  go flat, append a relocation table and self-relocate at entry.

`objcopy -O binary` on a dynamically-linked ELF discards the dynamic section
and relocations and produces a file that will not run. Do not do it.

## 9. Firmware-specific offsets are everywhere

Any code that reads kernel structures (process tables, kernel base, jail
addresses) uses offsets that change per firmware. The SDK keeps its own in
`crt/patch.c` and `crt/kernel.c`; your detection code keeps its own. A payload
that works on 9.00 can silently misbehave on 13.52 for this reason alone.

## 10. Hot-swap without rebooting

To stop a running daemon, load an evict helper so the kernel does the unload.
Inside a sandbox, `kill()` returns `EPERM`, so you cannot signal another
process yourself. Load the evict payload with `sceKernelLoadStartModule` and
let the kernel tear the old module down.
