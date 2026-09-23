# Build Freshness Debugging Guide

See also: [reproducible-builds.md](reproducible-builds.md) for verifying ROM reproducibility.

## The Problem

Changes to source files in `initrd/` or other build dependencies were not being packed into `initrd.cpio.xz`, causing stale artifacts in the final ROM. The test system showed old commit hashes in `/tmp/config` even after rebuilding.

## initrd.cpio.xz Composition

The final initrd.cpio.xz is built from **6 separate cpio archives**:

| CPIO | Source | Built by |
|------|--------|----------|
| `dev.cpio` | `blobs/dev.cpio` | Static (pre-built) |
| `modules.cpio` | Linux kernel modules | modules/linux |
| `tools.cpio` | Binaries + libraries + **/etc/config** | Makefile |
| `board.cpio` | Board-specific scripts | Makefile |
| `data.cpio` | Configurable data files | Makefile |
| `heads.cpio` | initrd/* scripts | Makefile |

The final packaging rule:
```makefile
$(build)/$(initrd_dir)/initrd.cpio.xz: $(initrd-y)
```

### xz recipe

The final `initrd.cpio.xz` is compressed with:

```makefile
xz --check=crc32 $(INITRD_XZ_ARCH_FILTER) $(INITRD_XZ_FILTER)
```

| Variable | Value | Applies to |
|----------|-------|------------|
| `INITRD_XZ_ARCH_FILTER` | `--x86` | x86 targets only; empty otherwise |
| `INITRD_XZ_FILTER` | `--lzma2=preset=9e,lc=4,lp=0,pb=1,mf=bt3,nice=128` | all targets |

- The x86 BCJ filter only helps x86 code, and the kernel needs
  `CONFIG_XZ_DEC_X86` to decompress it, so it is gated to x86 targets.
- The chain must be BCJ then LZMA2; a bare `-9`/`-9e` cannot be combined
  with `--x86` because it replaces the chain, so the level rides on the
  LZMA2 filter as `preset=9e`.
- The comma must live in a variable: make splits `$(call)` arguments on
  commas before expansion.
- `--check=crc32` because the kernel's XZ decoder rejects CRC64.
- Measured combined gain is 21,056 B (~20.6 KiB) compressed on t480 versus
  `preset=9e` alone. The `lc/lp/pb` part alone is 12,136 B; the
  `mf=bt3,nice=128` part alone is 8,920 B raw / 8,704 B padded.

## Build Flow

### 1. Initrd Build (Makefile)

```
tools.cpio: binaries + libraries + /etc/config (from board .config)
board.cpio: boards/BOARD/initrd/* scripts  
heads.cpio: initrd/* scripts (oem-factory-reset.sh, etc.)
data.cpio: module data files

initrd.cpio.xz = cpio-clean(dev.cpio + modules.cpio + tools.cpio + board.cpio + data.cpio + heads.cpio)
```

**tools.cpio contains /etc/config**:
- Exports all CONFIG_* variables from board config
- GIT_HASH, GIT_STATUS, CONFIG_BOARD

### 2. coreboot Build (modules/coreboot)

```
.build rule: depends on bzImage + initrd.cpio.xz
```

coreboot is configured with `CONFIG_LINUX_INITRD` pointing to initrd.cpio.xz. The initrd is embedded in the Linux kernel payload, not in CBFS.

### 3. Final Output

```
$(BOARD)/$(CB_OUTPUT_FILE) = coreboot-VERSION/board/coreboot.rom (copied and renamed)
$(BOARD)/$(CB_UPDATE_PKG_FILE) = .rom + sha256sum.txt in a zip
```

## Dependency Chain

The build system uses file dependencies + FORCE for consistent output:

| Target | Dependencies |
|--------|--------------|
| `heads.cpio` | `$(HEADS_INITRD_FILES)` (variable with find results) + FORCE |
| `board.cpio` | `$(BOARD_INITRD_FILES)` (variable with find results) + FORCE |
| `tools.cpio` | `$(initrd_bins)`, `$(initrd_libs)`, `etc/config` |
| `etc/config` | `$(CONFIG)` |
| `initrd.cpio.xz` | `$(initrd-y)` (all cpio components) |
| `coreboot .build` | `bzImage`, `initrd.cpio.xz` |

**Key insight**: Using `$(shell find ...)` directly in prerequisites causes Make to evaluate the file list ONCE at parse time. Instead, we use variable assignment:
```makefile
HEADS_INITRD_FILES := $(shell find $(pwd)/initrd -type f 2>/dev/null)
$(build)/$(initrd_dir)/heads.cpio: $(HEADS_INITRD_FILES) FORCE
```

This ensures the file list is re-evaluated each time Make runs, properly tracking source file changes.

**Why FORCE?** Make may skip the recipe if it thinks the target is up-to-date based on file timestamps. FORCE ensures the recipe always runs so our do-cpio macro can use `cmp` to check if content actually changed. This provides:
1. **Consistent output** - always shows "CPIO" or "UNCHANGED"
2. **Efficient rebuilds** - actual filesystem write only happens when content differs

Each target only rebuilds when its dependencies change:
- `cmp` checks if content actually changed before writing output
- Timestamps are preserved when content is identical

## Verifying Freshness

### Check if your changes are in the built initrd:

```bash
# Extract initrd to temp directory
cd /tmp && rm -rf initrd_check && mkdir initrd_check
xz -dc < build/x86/BOARD/initrd.cpio.xz | cpio -idm -D /tmp/initrd_check

# Check your file
grep "your_pattern" /tmp/initrd_check/path/to/file
```

### Check /etc/config (GIT_HASH, CONFIG_*):

```bash
xz -dc < build/x86/BOARD/initrd.cpio.xz | cpio -idm -D /tmp/initrd_check
cat /tmp/initrd_check/etc/config | grep -E "GIT_HASH|CONFIG_BOARD"
```

### List all cpio contents:

```bash
xz -dc < build/x86/BOARD/initrd.cpio.xz | cpio -it | head -30
```

### Compare timestamps:

```bash
# Source file
ls -la initrd/bin/oem-factory-reset.sh

# Built initrd
ls -la build/x86/BOARD/initrd.cpio.xz

# coreboot ROM
ls -la build/x86/BOARD/coreboot.rom
```

If source is newer but initrd.cpio.xz is older, it wasn't rebuilt.

### Check what Makefile thinks is needed:

```bash
./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-hotp -n
```

## Building Fresh

The Docker wrapper is the default for reproducible and CI builds; `nix develop`
is the local equivalent.  See `doc/docker.md` for the wrapper.

```bash
# Full rebuild (Docker)
./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-hotp

# Full rebuild (local)
nix develop --command make BOARD=qemu-coreboot-fbwhiptail-tpm2-hotp
```

Rebuild guidance lives in the `Rebuild helpers` section of `doc/modules.md`.
Escalation order, least to most destructive:

1. plain `make BOARD=<board>`
2. targeted `<module>.clean`, `touch <source>`, or `rm -rf build/x86/<board>`
3. `modules.clean`
4. canary purge (`real.remove_canary_files-extract_patch_rebuild_what_changed`)
5. `real.clean` (last resort)
