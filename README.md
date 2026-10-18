# goldhen-payload-template

A minimal, working starting point for a PS4 **GoldHEN payload**: clone it,
build a loadable `payload.elf`, and read the notes that save a weekend.

It builds against the [ps4-payload-dev SDK](https://github.com/ps4-payload-dev/sdk)
(daemon-world linkage) and deploys with `orbis-deploy` to elfldr or GoldHEN
BinLoader.

The documentation is the point. It collects what actually went wrong bringing
a real payload up on hardware, in [docs/LEARNINGS.md](docs/LEARNINGS.md):
linkage, the SDK firmware gate, loader one-shot rules, TLS and dialog init,
and how to observe a console that gives you no debugger.

## Quick start

```sh
# 1. build the SDK from git (never the release ZIP)
./scripts/setup_sdk.sh

# 2. build the payload
PS4_PAYLOAD_SDK=~/ps4-payload-sdk make
# -> build/payload.elf

# 3. confirm daemon-world linkage
make check

# 4. deploy to elfldr (edit/build/deploy loop)
make deploy PS4_HOST=192.168.1.x PS4_PORT=9021
```

Watch the kernel log while you deploy (see [docs/DEBUGGING.md](docs/DEBUGGING.md)):

```sh
nc 192.168.1.x 3232
```

## The rules that matter most

- **Linkage is the silent killer.** A spawned payload that imports app-world
  `libkernel.so` dies before `main()` with no log. Daemon-world only:
  `libkernel_web.sprx`, `libSceLibcInternal.sprx`, `libSceNet.sprx`.
- **Build the SDK from git.** A firmware missing from `crt/patch.c` exits
  before `main()`, silently. Check the source, not a byte-scan of the ELF.
- **9020 is one-shot.** Never port-check BinLoader; the first connection must
  carry the payload. Use elfldr 9021 to iterate.
- **`log.txt` absent means "never executed".** It never means "crashed later".
- **Never FTP a PRX or SELF.** The console converts SELF to raw ELF on write.
  Ship plugins in a PKG.

Full detail and evidence: [docs/LEARNINGS.md](docs/LEARNINGS.md).

## Layout

```
Makefile              build, check (linkage gate), deploy
src/main.c            starter payload: klog output, args, a notification
scripts/setup_sdk.sh  clone + build the SDK from git, print firmware cases
docs/LEARNINGS.md     the ten lessons, with the evidence
docs/BUILDING.md      toolchain, SDK from git, flat bin vs ELF
docs/LOADING.md       loaders, ports, one-shot rule, deploy, autoload
docs/DEBUGGING.md     klog / FTP / screenshots, proof markers, checklist
```

## Requirements

- `clang-18`, `lld-18`, `llvm-18` (or newer) with `llvm-config` on `PATH`.
- A PS4 on a jailbroken firmware with GoldHEN or elfldr, reachable on your LAN.

## License

MIT for this template's own files. The SDK you link against is GPL-3.0, so
distributed payloads follow the SDK's terms. See [LICENSE](LICENSE).

---

Built while shipping [orbisRPC](https://github.com/SirHumza/orbisRPC); the
hard-won parts are credited there.
