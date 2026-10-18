# Building

## Requirements

- `clang-18`, `lld-18`, `llvm-18` (or newer) with `llvm-config` on `PATH`.
- The **ps4-payload-dev SDK, built from git**. Never the release ZIP.

macOS: `brew install llvm` (or MacPorts `llvm-18`). Linux:
`apt install clang-18 lld-18 llvm-18`.

## One-time SDK setup

```sh
./scripts/setup_sdk.sh                 # installs to ~/ps4-payload-sdk
# or pin a commit for reproducibility:
PS4_SDK_REF=<commit> PS4_SDK_DEST=~/ps4-payload-sdk ./scripts/setup_sdk.sh
```

The script clones `ps4-payload-dev/sdk`, checks out the ref, prints every
firmware case found in `crt/patch.c`, then builds and installs. Confirm your
console's firmware appears in that list before building anything.

Why git and not the ZIP: the SDK's CRT gates startup on a per-firmware table
and exits before `main()` for any firmware it does not list, with no log line.
Release builds lag the offsets. See [LEARNINGS.md](LEARNINGS.md) lesson 2.

## Build

```sh
PS4_PAYLOAD_SDK=~/ps4-payload-sdk make
# -> build/payload.elf
```

The Makefile includes the SDK's `toolchain/orbis.mk`, which sets `CC` to
`orbis-clang` and links the daemon-world defaults
(`-lkernel_web -lSceLibcInternal -lSceNet`). Never add an app-world `.so`.

## Verify linkage

```sh
make check
```

This fails if the payload imports `libkernel.so` and prints the `NEEDED` list.
Expected:

```
libkernel_web.sprx
libSceLibcInternal.sprx
libSceNet.sprx
```

## Flat `.bin` vs ELF

This template builds a **dynamically-linked ELF**, which is what elfldr and
GoldHEN BinLoader expect. A flat `.bin` (libPS4 style) is a different world:
no dynamic linker, no relocations on load, static pointer tables break. Do not
run `objcopy -O binary` on the ELF; it discards the dynamic section and
relocations. See [LEARNINGS.md](LEARNINGS.md) lesson 8 if you need a flat
image.
