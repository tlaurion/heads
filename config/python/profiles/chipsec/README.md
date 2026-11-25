# chipsec CPython profile

Additive profile for running CHIPSEC userspace tools in Heads initrd.

Status: **draft/opt-in**. Not enabled by default; wyng profile remains default.

Rationale:
- CHIPSEC (Linux userspace) imports broad stdlib including logging, csv, concurrent/multiprocessing, plistlib, pprint, decimal.
- `lzma`/`_lzma` intentionally omitted until an xz/liblzma module is wired into Heads; adding the name alone does not build the C extension.
- Keep closed allowlist explicit; expand only with smoke-tested imports.

Notes:
- If chipsec needs LZMA, add a liblzma/xz module and wire cpython build deps; then re-add `lzma`/`_lzma`.
- CHIPSEC helper/kernel driver strategy is separate from Python packaging.
- Add modules only after tracing actual selected CHIPSEC commands.

## Heads module dependency contract (draft)

chipsec (Python userspace):
- CONFIG_CHIPSEC=y
- requires: CONFIG_CPYTHON=y (auto-adds CPYTHON profile `chipsec`)
- python profile adds: csv,logging,concurrent,multiprocessing,plistlib,pprint,decimal,_decimal
- build deps: cpython, setuptools? (only if packaging), musl_dep
- runtime deps: chipsec helper strategy; for full functionality likely chipsec.ko
- initrd staging: TBD (site-packages/chipsec + /bin/chipsec_util/chipsec_main wrappers)

chipsec-km (out-of-tree kernel module, required for driver-backed helper):
- CONFIG_CHIPSEC_KM=y (proposed)
- requires: CONFIG_CHIPSEC=y, CONFIG_LINUX=y, kernel modules support in target kernel, busybox insmod/rmmod/lsmod as needed
- build deps: linux kernel build dir ($(build)/$(linux_dir)), nasm, cross toolchain
- artifact: chipsec.ko staged into modules.cpio/lib/modules or /lib/modules load path
- runtime: insmod/modprobe path; chipsec linuxhelper looks for chipsec.ko / modprobe chipsec

## Explicit dependency matrix (Heads)

### Python (chipsec userspace)
- REQUIRED: `CONFIG_CPYTHON=y`
- PROFILE: `chipsec` (auto-added when `CONFIG_CHIPSEC=y`, else set `CPYTHON_PROFILES_EXTRA=chipsec`)
- Extra keeplist needs (unioned): stdlib adds `csv,logging,concurrent,multiprocessing,plistlib,pprint,decimal,_pydecimal`; dynload adds `_decimal` (see `config/python/profiles/chipsec/*`)
- Setup.local: intersection of selected profiles removes `lzma` disable (enables `_lzma`); `curses/dbm/nis/ssl` remain disabled by wyng base unless another profile enables them (none do here)
- Staged as: `chipsec` package under `lib/python$(MM)/site-packages/chipsec` + any entrypoints/wrappers (TODO: not yet packaged)

### Kernel driver (required for Linux `linuxhelper` full behavior)
- REQUIRED (for driver-backed): build/install `chipsec.ko` (from `drivers/linux/`, x86 asm) against the Heads-built kernel (`$(build)/$(linux_dir)`), stage into initrd `modules.cpio`
- Runtime load: `insmod.sh` (BusyBox `insmod`) measures+extends PCR5 then loads; kernel must have `CONFIG_MODULES`/module support enabled (verify board/kernel config)
- BusyBox: `CONFIG_INSMOD=y`, `CONFIG_LSMOD=y` enabled in current `config/busybox.config`; `modprobe/rmmod` not enabled (insmod.sh uses `busybox insmod`)
- Heads TODO: add `modules/chipsec-km` (or equivalent) with `depends := linux`, build step `make -C $(KSRC) M=... modules`, copy `chipsec.ko` into module staging dir, ensure load order (kernel modules loaded after kernel/initramfs setup as per board flow)

### “Dynamic per module” contract (intended)
- Today: explicit hook in `modules/cpython` sets `CPYTHON_PROFILES_EXTRA += chipsec` when `CONFIG_CHIPSEC=y`.
- Target: modules declare `$(name)_cpython_profile` / `$(name)_cpython_profiles` and cpython unions them for `modules-y` (less fragile than editing cpython per consumer). Not yet implemented.
