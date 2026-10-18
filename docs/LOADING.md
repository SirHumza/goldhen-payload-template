# Loading the payload

## The three loaders

| Loader | Port | Behavior |
|---|---|---|
| GoldHEN settings-page payloader | 9090 | Accepts bytes, then its loader thread may segfault. ELF support needs GoldHEN >= v2.4b18.5. |
| GoldHEN BinLoader server | 9020 | One-shot per arm. An empty connect burns the arm. |
| elfldr (ps4-payload-dev) | 9021 | Serves until reboot. Best iteration harness. |

## Deploy

The SDK ships `orbis-deploy`. The Makefile wraps it:

```sh
make deploy PS4_HOST=192.168.1.x PS4_PORT=9021
```

On port 9020 the send must be blind: do not probe first, the first connection
carries the payload.

```sh
# blind send to BinLoader, no port check
nc 192.168.1.x 9020 < build/payload.elf
```

Send to elfldr (9021) for a normal edit/build/deploy loop.

## Autoload paths

If the console has GoldHEN, payloads left in these directories run at
jailbreak:

- `/data/GoldHEN/payloads/` - autoloaded at jailbreak
- `/data/payloads/` - Payload Guest scan directory

Autoloading is convenient but makes "did my build run?" harder to read. Prefer
elfldr while developing.

## PRX and SELF go in a PKG

Never FTP-upload a PRX or SELF: the console-side write path converts SELF
containers to raw ELF and the bytes arrive wrong. Deliver plugins by PKG
install. See [LEARNINGS.md](LEARNINGS.md) lesson 5.
