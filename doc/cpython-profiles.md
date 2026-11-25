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
  Splits INSTALL (build-required superset) from RUNTIME (profile-only, staged).
- `config/python/profiles/base/` — minimal common CPython runtime.
- `config/python/profiles/wyng/` — wyng runtime additions over base.
- `config/python/profiles/chipsec/` — opt-in chipsec additions over base.
- `modules/cpython` — profile selection, merge stamp, prune, smoke aggregation.
- `modules/wyng-backup` — declares wyng profile/smoke/build requirements.
- `modules/chipsec` — draft module; declares chipsec profile/smoke/build reqs.
- `modules/cryptodome`, `modules/python-zstd` — declare build-required stdlib/dynload and smoke PYTHONPATH.

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

`modules/chipsec` is draft/opt-in and explicitly documented in-module.

Implemented:
- CPython profile `chipsec` selected via module-driven merge.
- Per-board smoke imports declared by module and validated by `cpython_test`.

Not implemented / TODO:
- CHIPSEC Python package/entrypoint staging into initrd.
- `lzma/_lzma`: omitted until xz/liblzma module + CPython build wiring exists.
- Kernel-driver path (`chipsec.ko`) as separate module/contract.
- Automated QEMU command-flow QA for CHIPSEC; current smoke is import-only.

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

## Module-Owned Requirements (explicit)

Modules own CPython requirements. `modules/cpython` only aggregates enabled
modules for the selected board.

| Declaration | Owner | Purpose | Validation |
|---|---|---|---|
| `<mod>_cpython_profiles` / `_cpython_profile` | module needing runtime profile | Adds profile delta (`config/python/profiles/<name>/`) | `make ... cpython_profile` stamp, board build |
| `<mod>_cpython_build_required_stdlib` | module built against target CPython | Stdlib kept in INSTALL build tree only (not staged runtime) | module build, `cpython_smoke` |
| `<mod>_cpython_build_required_dynload` | module built against target CPython | Dynload kept in INSTALL build tree only | module build, `cpython_smoke` |
| `<mod>_cpython_runtime_required_encodings` | module needing extra encodings | Generated per-board `build/<board>/cpython-runtime-required-encodings.txt` | runtime smoke/import trace |
| `<mod>_cpython_smoke_imports` | module/runtime consumer | Per-board smoke imports aggregated by `modules/cpython` | `make BOARD=<board> cpython_smoke` |
| `<mod>_cpython_smoke_pythonpath` | module staged as tools.cpio tree | Extra PYTHONPATH for smoke against build tree artifacts | `make BOARD=<board> cpython_smoke` |

Base defaults (always present): base profile; base smoke imports
`sys os io encodings codecs stat posixpath genericpath warnings site`; base
runtime encodings `__init__.py aliases.py ascii.py cp437.py latin_1.py utf_8.py`.

## Per-Board Smoke/Test

Explicit target: `cpython_test` (alias of `cpython_smoke`).

```sh
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython cpython_test
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-wyng cpython_test
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-chipsec cpython_test
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-wyng-chipsec cpython_test
```

Smoke runs target Python through musl loader with `INSTALL/lib:lib64` and
module-declared PYTHONPATH for tools.cpio-staged packages. It validates
module-declared imports; it does not boot QEMU or exercise full command flows.
It is a per-board/module requirement gate, not a full runtime integration test.

## Adding a Module Requirement

1. Add/extend `config/python/profiles/<name>/` only for runtime stdlib/dynload
   needed in initrd.
2. Declare `<mod>_cpython_profiles += <name>` and `<mod>_cpython_smoke_imports`.
3. If module builds against target CPython, declare
   `<mod>_cpython_build_required_{stdlib,dynload}` (build-only; not staged).
4. If module is staged as tools.cpio package, declare
   `<mod>_cpython_smoke_pythonpath`.
5. Run `cpython_smoke` for affected boards and a board build.
