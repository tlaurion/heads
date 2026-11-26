# CPython Profiles (module-driven)

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
  selected profile disables it. Capability enablement is profile-owned; the
  merge script does not force `_hashlib` (or any other module) to stay enabled.
- Keep-lists are a closed allowlist: missing entries cause runtime import
  failures; validate with smoke/import traces before trimming.

## Packaging reference

`base` follows OpenWrt's `python3-base` intent: interpreter startup plus the
small smoke-import set, not OpenWrt's larger `python3-light` default. Module
profiles behave like OpenWrt's split stdlib/capability packages; capability
build/runtime dependencies are declared by the module via
`<mod>_cpython_depends`. Build mechanics and musl/reproducibility choices are
checked against Alpine's musl CPython APKBUILD. See also
[build-freshness.md](build-freshness.md#toolscpio-vs-datacpio--staging-rule),
[modules.md](modules.md), [reproducible-builds.md](reproducible-builds.md),
[logging.md](logging.md), and [ux-patterns.md](ux-patterns.md).

## Selection

`modules/cpython` always includes `base`, then adds:

1. `CPYTHON_PROFILE` / `CPYTHON_PROFILES_EXTRA` (manual/debug overrides).
2. `*_cpython_profile` / `*_cpython_profiles` declared by enabled `modules-y`.

Profiles are de-duplicated while preserving order. The merge stamp depends on
the selected profile inputs. Because CPython's source configure tree is shared,
a content-checked board/profile identity also forces reconfigure when make
switches boards; each board then gets its own pruned runtime tree.

## Chipsec Status

`modules/chipsec` is draft/opt-in and explicitly documented in-module.

Implemented:
- CPython profile `chipsec` selected via module-driven merge.
- Full pinned CHIPSEC package staged under site-packages with a `/bin/chipsec`
  wrapper; the module owns its OpenSSL/_hashlib requirement.
- Per-board imports validated by `cpython_test`.
- Automated QEMU CLI smoke for version/help and module enumeration, including
  the combined wyng + chipsec board.

Not implemented / TODO:
- `lzma/_lzma`: omitted until xz/liblzma module + CPython build wiring exists.
- Kernel-driver path: `modules/chipsec-km` builds/stages `/lib/modules/chipsec.ko`
  (opt-in, no auto-load). QEMU `insmod` and `/dev/chipsec` creation are verified;
  hardware-backed checks remain unverified.

## Build / Verification

Use docker_repro for reproducible builds:

```sh
HEADS_DISABLE_USB=1 script -qefc './docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-wyng' /tmp/wyng-build.log </dev/null >/dev/null 2>&1
```

After deep build breakage, prefer Makefile helpers in escalation order:
`real.remove_canary_files-extract_patch_rebuild_what_changed`, then
`real.clean` as last resort.

Verify default wyng profile:

- `cpython_test` logs `CPYTHON-PROFILE base wyng`; with `CONFIG_CHIPSEC=y`
  it logs `base chipsec wyng`.
- Board build dir contains `cpython-stdlib-keep.txt`,
  `cpython-dynload-keep.txt`, and `cpython-Setup.local`.
- Initrd contains `bin/python3`, `bin/python3.13`, `lib/python3.13/...`;
  the wyng profile includes `_hashlib`; no `_lzma` for wyng-only profile; no
  doubled `lib/python3.13/python3.13`.

## Measured Size Impact

Measured with the pinned Docker environment on 2026-11-25. “Before” is the
earlier branch build before board-scoped runtime pruning and dependency
minimization; “after” is the final minimized four-board build. Sizes are bytes;
every ROM remains the fixed 16 MiB flash image.

| Board profile | Runtime files | `tools.cpio` before → after | `initrd.cpio.xz` before → after |
|---|---:|---:|---:|
| base | 752,561 | 26,463,232 → 20,441,088 (−6,022,144) | 7,909,376 → 6,782,464 (−1,126,912) |
| chipsec | 4,455,338 | 25,924,608 → 28,136,448 (+2,211,840) | 7,792,128 → 8,084,480 (+292,352) |
| wyng + chipsec | 6,276,837 | 28,440,064 → 31,945,216 (+3,505,152) | 8,480,256 → 9,015,808 (+535,552) |
| wyng | 5,384,785 | 28,435,968 → 27,076,096 (−1,359,872) | 8,480,256 → 8,300,544 (−179,712) |

The base runtime contains no `lib-dynload/*.so`; chipsec and wyng pay only for
their selected capability profiles. The full CHIPSEC package adds about 3.9 MiB
uncompressed. Against the matching non-CPython QEMU initrd measured earlier at
5,671,936 bytes (not a pristine `origin/master` rebuild), base adds 1,110,528
compressed bytes and functional chipsec adds 2,412,544. The packaged chipsec
profile itself adds 1,302,016 compressed bytes over CPython base.

## Module-Owned Requirements (explicit)

Modules own CPython requirements. `modules/cpython` only aggregates enabled
modules for the selected board.

| Declaration | Owner | Purpose | Validation |
|---|---|---|---|
| `<mod>_cpython_profiles` / `_cpython_profile` | module needing runtime profile | Adds profile delta (`config/python/profiles/<name>/`) | `make ... cpython_profile` stamp, board build |
| `<mod>_cpython_build_required_stdlib` | module built against target CPython | Stdlib kept in INSTALL build tree only (not staged runtime) | module build, `cpython_smoke` |
| `<mod>_cpython_build_required_dynload` | module built against target CPython | Dynload kept in INSTALL build tree only | module build, `cpython_smoke` |
| `<mod>_cpython_depends` | module/profile owning an external capability | Adds CPython build-order dependencies (for example libffi/openssl/zlib); config gates come from `modules/<feature>.requires` | module configure/build |
| `<mod>_cpython_runtime_required_encodings` | module needing extra encodings | Generated per-board `build/<board>/cpython-runtime-required-encodings.txt` | runtime smoke/import trace |
| `<mod>_cpython_smoke_imports` | module/runtime consumer | Per-board smoke imports aggregated by `modules/cpython` | `make BOARD=<board> cpython_smoke` |
| `<mod>_cpython_smoke_pythonpath` | module staged as tools.cpio tree | Extra PYTHONPATH for smoke against build tree artifacts | `make BOARD=<board> cpython_smoke` |

Base defaults (always present): base profile; base smoke imports
`sys os io encodings codecs stat posixpath genericpath site sysconfig
_collections_abc abc types`; base runtime encodings
`__init__.py aliases.py ascii.py cp437.py latin_1.py utf_8.py`.

## Per-Board Smoke/Test

Explicit target: `cpython_test` (alias of `cpython_smoke`).

```sh
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython cpython_test
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-wyng cpython_test
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-chipsec cpython_test
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-wyng-chipsec cpython_test
```

Smoke runs target Python through the musl loader with
`PYTHONHOME=build/<arch>/<board>/python-runtime`, `INSTALL/lib:lib64`, and
module-declared PYTHONPATH for tools.cpio-staged packages. It validates
module-declared imports; it does not boot QEMU or exercise full command flows.
It is a per-board/module requirement gate, not a full runtime integration test.
The four QA boards boot into a serial test shell. `make BOARD=<board> qemu_smoke`
runs their command-flow plans automatically; see
[qemu.md](qemu.md#cpythonchipsec-qa-test-shell).

## Adding a Module Requirement

1. Add/extend `config/python/profiles/<name>/` only for runtime stdlib/dynload
   needed in initrd.
2. Declare `<mod>_cpython_profiles += <name>` and `<mod>_cpython_smoke_imports`.
3. If module builds against target CPython, declare
   `<mod>_cpython_build_required_{stdlib,dynload}` (build-only; not staged).
4. If module is staged as tools.cpio package, declare
   `<mod>_cpython_smoke_pythonpath`.
5. Declare config-gate requirements in `modules/<feature>.requires`; the global
   Makefile enables them before module load. Keep build order in `_depends`.
6. Run `cpython_smoke` for affected boards and a board build.
