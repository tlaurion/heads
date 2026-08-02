# Reproducible Builds

See `doc/docker.md` for build-environment reproducibility.

All module and component tarballs are downloaded via `bin/fetch_source_archive.sh`,
which tries the primary source first, then falls back to the Purism package mirrors
(`storage.puri.sm`, `storage.puri.st`).  Every download attempt is logged to
`build/mirror_fallbacks.log` with timestamps — cached hits, primary successes,
and mirror fallbacks are all recorded.

These practices follow the [reproducible-builds.org](https://reproducible-builds.org/)
project's documentation.  In brief, a build is reproducible if the same source
produces bit-for-bit identical output across independent environments.  This
requires eliminating non-determinism from three sources, per the project's
[documentation](https://reproducible-builds.org/docs/):

- **Timestamps**: `SOURCE_DATE_EPOCH` ([spec](https://reproducible-builds.org/specs/source-date-epoch/))
  replaces wall-clock time in `__DATE__`, `__TIME__`, and similar macros.
- **Build paths**: `-fdebug-prefix-map` maps absolute paths to stable ones
  ([docs](https://reproducible-builds.org/docs/build-path/)).
- **Toolchain non-determinism**: compiler/linker flags that produce
  varying output (section padding, debug compression, hash-table ordering)
  are pinned or disabled
  ([docs](https://reproducible-builds.org/docs/deterministic-build-systems/)).

## Practices Applied

### Cross-compiler (musl-cross-make)

| Flag | Source |
|---|---|
| `BUILD = x86_64-pc-linux-gnu` | in `musl-cross-make_configure` |
| `-Wa,--no-pad-sections` | in `musl-cross-make_configure` |
| `--with-debug-prefix-map=$(pwd)=.` | in `musl-cross-make_configure` |
| `--enable-compressed-debug-sections=no` | in `musl-cross-make_configure` |
| `SOURCE_DATE_EPOCH=$(git log -1 --format=%ct ...)` | in `musl-cross-make_target` |

The four config flags are written into `config.mak` by `musl-cross-make_configure`.

### Userland (all modules)

| Flag | Where | Source |
|---|---|---|
| `-fdebug-prefix-map=$(pwd)=heads` | `heads_cc` | in the `heads_cc` definition |
| `-gno-record-gcc-switches` | `heads_cc` | in the `heads_cc` definition |

`heads_cc` is defined in the Makefile and used as `CC` by every userland module.

### Kernel build flags

| Flag | Source |
|---|---|
| `EXTRA_FLAGS := -fdebug-prefix-map=$(pwd)=heads -gno-record-gcc-switches` | in the `linux_target` module |
| `KBUILD_BUILD_TIMESTAMP="1970-00-00"` | in the kernel build variables |
| `KBUILD_BUILD_HOST=linuxboot` | in the kernel build variables |

`EXTRA_FLAGS` is passed to the kernel as `AFLAGS_KERNEL`, `CFLAGS_KERNEL`, and `CFLAGS_MODULE` (in the kernel flag passthrough).

### Prefix overrides for reproducibility

`modules/gpg` (and siblings `modules/gpg2`, `modules/e2fsprogs`,
`modules/exfatprogs`, `modules/pinentry`) override `--prefix` on the
configure line to a fixed path (e.g. `--prefix "/"`).  This ensures the
generated Makefiles carry a known prefix; the install target then
redirects output to the actual build tree via `DESTDIR="$(INSTALL)"`.

### Busybox-specific

| Change | Source |
|---|---|
| `patches/busybox-1.36.1/0004-trylink-reproducible.patch` disables ld.bfd `--gc-sections` when `SOURCE_DATE_EPOCH` is set | in the patch |
| `SOURCE_DATE_EPOCH=0` in `busybox_target` | in `busybox_target` |
| Install rule bypasses `make install`; copies the binary and runs `applets/install.sh` directly | in the install rule |

### openssl

`patches/openssl-3.0.8.patch` patches `util/mkbuildinf.pl` so the recorded build
date comes from `$ENV{'SOURCE_DATE_EPOCH'}` (defaulting to `'0'`) instead of
`time()`, and replaces the recorded compiler flags with a fixed literal.

## Verifying ROM Reproducibility

### Prerequisites
- Same git commit on both CI and local
- Build with `docker_repro.sh` locally (same Docker image as CI)

### Understanding hashes.txt

`build/$ARCH/$BOARD/hashes.txt` records the SHA256 of **every file inside every
cpio archive**, not just the cpio archives themselves.  Each cpio section is
separated by `-----` lines:

```
<hash>  /path/to/modules.cpio
-----
<hash>  ./lib/modules/usbhid.ko
<hash>  ./lib/modules/e1000e.ko
...
-----
<hash>  /path/to/tools.cpio
-----
<hash>  ./bin/busybox
<hash>  ./bin/kexec
...
-----
```

### GIT_HASH in /etc/config

`tools.cpio` contains `./etc/config`, which embeds `GIT_HASH` from `git rev-parse HEAD`
(in the `/etc/config` generation rule).  Every commit changes `GIT_HASH`, so `./etc/config` differs
between ANY two commits.  This cascades: `./etc/config` → `tools.cpio` →
`initrd.cpio.xz` → ROM.

When `./etc/config` is the **only** differing file inside `tools.cpio`, the
build is still reproducible — all binaries (busybox, kexec, gpg, etc.) are
byte-identical.  A binary mismatch (e.g. `./bin/busybox`) is the actual
reproducibility bug to investigate.

### Steps

1. Build locally and download CI `hashes.txt` for the same commit.

2. Compare ROM hashes — if they match, the build is reproducible. Done.
```bash
grep '\.rom' /tmp/ci-hashes.txt build/x86/EOL_t480-hotp-maximized/hashes.txt
```

3. If the ROM differs, step down: `initrd.cpio.xz`/`bzImage` → `tools.cpio` →
individual files.  The innermost differing file (e.g. `./bin/busybox`) is the
root cause — fix it and the cascade resolves.  `hashes.txt` records every file
at every level, so no diffoscope is needed until you've identified what differs.

4. For a comprehensive check:
```bash
diff <(grep '^[0-9a-f]\{64\}' /tmp/ci-hashes.txt | awk '{print $1}' | sort) \
     <(grep '^[0-9a-f]\{64\}' build/x86/EOL_t480-hotp-maximized/hashes.txt | awk '{print $1}' | sort)
```

`./etc/config` inside `tools.cpio` always differs between commits (contains
`GIT_HASH`).  Its cascade through `tools.cpio`/`initrd.cpio.xz`/ROM is expected;
only a binary mismatch is a reproducibility bug.
