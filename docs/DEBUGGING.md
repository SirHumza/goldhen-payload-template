# Debugging on-console

A payload has no debugger. Everything you learn comes from the kernel log, the
filesystem, and the notification area. Plan for that: make the first line your
payload prints unmistakable, and treat "nothing appeared" as a first-class
result.

## Channels

| Channel | Address | Use |
|---|---|---|
| Kernel log (klog) | TCP `:3232` | loader events, faults, `printf()` output |
| FTP | `:2121` (anonymous) | pull logs and dumps, push files |
| BinLoader | `:9020` | inject (one-shot, fire blind) |
| elfldr | `:9021` | inject and iterate |

`printf()` in a daemon-world payload goes to klog. Watch it live across the
send window:

```sh
nc 192.168.1.x 3232
# in another shell:
make deploy PS4_HOST=192.168.1.x PS4_PORT=9021
```

## Proof markers

| Question | Marker |
|---|---|
| Did the daemon start? | log file exists with its `start` line |
| Did networking work? | a `TLS ... established` line |
| Did the loader crash (not my payload)? | `signal 11 (SIGSEGV), thread GoldHENLoader`, fault address 0, right after `payload launched successfully` |

## Rules learned the hard way

1. Never port-check 9020 or 9090 before sending. Fire blind on tap.
2. klog is a live firehose. Capture across the send window, not after.
3. A log file that is absent always means "never executed", never "crashed
   later".
4. Build artifacts go stale fast. Verify the SHA before concluding anything
   about a run.
5. If your payload is silent and you linked an app-world library, that is the
   first suspect, not the console. Check `NEEDED` (see `make check`).

## Checklist for "nothing happens"

1. `llvm-readelf -d build/payload.elf | grep NEEDED` shows only
   `libkernel_web.sprx`, `libSceLibcInternal.sprx`, `libSceNet.sprx`.
2. The SDK was built from git and `crt/patch.c` lists your firmware.
3. The file name/ref matches what you sent (stale artifacts lie).
4. klog was captured during the send, not after.
5. If it still dies: read the loader signature in klog. A `GoldHENLoader`
   segfault is the loader, not your code.
