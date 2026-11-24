# CPython Profiles (wyng-poc)

Additive, per-profile CPython stdlib/extension selection. Modules declare
Python runtime needs; `modules/cpython` merges selected profiles into
board-local keep-lists and prunes the CPython install.

## Goal

- Keep wyng default behavior intact.
- Let modules add CPython stdlib/extension requirements without editing the
  wyng profile.
- Keep CPython base minimal; module profiles are additive deltas over base.

## Files

- `bin/cpython-profile-merge.sh` — merges selected profiles into:
  - `build/<arch>/<board>/cpython-stdlib-keep.txt`
  - `build/<arch>/<board>/cpython-dynload-keep.txt`
  - `build/<arch>/<board>/cpython-Setup.local`
  - `build/<arch>/<board>/cpython-profiles.txt`
- `bin/cpython-prune.sh` — prunes stdlib/lib-dynload using merged keep-lists.
- `config/python/profiles/base/` — minimal common CPython runtime.
- `config/python/profiles/wyng/` — wyng runtime additions over base.
- `config/python/profiles/chipsec/` — opt-in chipsec additions over base.
- `modules/cpython` — profile selection, merge stamp, configure/install/prune.
- `modules/wyng-backup` — declares `wyng-backup_cpython_profiles += wyng`.
- `modules/chipsec` — draft module; declares `chipsec_cpython_profiles += chipsec`.

## Profile Format

Each profile directory contains:

- `stdlib-keep.txt` — stdlib entries to keep (top-level Lib entries).
- `dynload-keep.txt` — lib-dynload basenames to keep.
- `setup.local.disabled` — CPython `Modules/Setup.local` disable directives.

Merge semantics:

- **Keep-lists are unioned.** Module profiles should be deltas over `base`.
- **Setup.local disables are intersected.** A module is disabled only if every
  selected profile disables it. `_hashlib` is never disabled.
- Keep-lists are a closed allowlist: missing entries cause runtime import
  failures; validate with smoke/import traces before trimming.

## Selection

`modules/cpython` always includes `base`, then adds:

1. `CPYTHON_PROFILE` / `CPYTHON_PROFILES_EXTRA` (manual/debug overrides).
2. `*_cpython_profile` / `*_cpython_profiles` declared by enabled `modules-y`.

Profiles are de-duplicated while preserving order. The merge stamp records
selected profiles and input hashes; changing profiles forces reconfigure/prune.

## Chipsec Status

`modules/chipsec` is draft/opt-in. Python deps are modeled by the chipsec
profile; full Linux helper capability also requires an out-of-tree `chipsec.ko`
built against the Heads kernel and loaded in initrd (`insmod`/modules.cpio).
Kernel-module bundling is not implemented.

## Build / Verification

Use docker_repro for reproducible builds:

```sh
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-wyng -j"$(nproc)"
```

After deep build breakage, prefer Makefile helpers in escalation order:
`real.remove_canary_files-extract_patch_rebuild_what_changed`, then
`real.clean` as last resort.

Verify default wyng profile:

- `make -n BOARD=qemu-coreboot-fbwhiptail-tpm2-wyng /path/to/cpython-profile.stamp`
  selects `base wyng`; with `CONFIG_CHIPSEC=y` selects `base chipsec wyng`.
- Board build dir contains `cpython-stdlib-keep.txt`,
  `cpython-dynload-keep.txt`, `cpython-Setup.local`, `cpython-profiles.txt`.
- Initrd contains `bin/python3`, `bin/python3.13`, `lib/python3.13/...`,
  `_hashlib`; no `_lzma` for wyng-only profile; no doubled
  `lib/python3.13/python3.13`.
