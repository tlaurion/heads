# chipsec CPython profile (draft)

Additive CPython profile for CHIPSEC userspace on Heads. **Opt-in, draft**.

## Status

- **Implemented**: module-driven profile merge + per-board CPython smoke imports.
- **Not implemented**: CHIPSEC Python package staging, entrypoints/wrappers,
  automated QEMU boot/command-flow QA.
- **Draft kernel path**: `chipsec-km` builds/stages `chipsec.ko`; see below.

## Contract

- Selected by `modules/chipsec` via `chipsec_cpython_profiles += chipsec`.
- `modules/chipsec.requires` enables `CONFIG_CPYTHON` when CHIPSEC is selected.
- Keep-lists are closed allowlists; add entries only with traced CHIPSEC
  command/import evidence and smoke validation.

## Runtime additions over `base`

- stdlib: `csv`, `logging`, `concurrent`, `multiprocessing`, `plistlib`,
  `pprint`, `decimal` (and supporting stdlib pulled by profile keep-list).
- dynload: the traced smoke closure (`_csv`, `_datetime`, `_decimal`, `_json`,
  `_multiprocessing`, `_opcode`, `_pickle`, `_posixshmem`, `_posixsubprocess`,
  `_socket`, `_struct`, `array`, `binascii`, `math`, `pyexpat`, `select`, `zlib`).
- `setup.local.disabled`: disables optional capabilities not required by the
  chipsec profile; module/profile data owns enablement.

## Explicit omissions

- `lzma/_lzma`: omitted intentionally. Target CPython does not build `_lzma`
  without an xz/liblzma module and cpython build wiring. Do not add name-only
  entries; re-add only after dependency wiring is verified.
- `ssl`, `curses`, `dbm`, `nis`, `_uuid`: remain disabled unless a traced CHIPSEC
  path requires them and security/size impact is reviewed.

## Validation

```sh
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-chipsec cpython_test
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-wyng-chipsec cpython_test
```

This validates module-declared Python imports through target Python. It does
**not** boot QEMU, run `chipsec_main.py`, or validate kernel-driver behavior.

## QEMU / automated QA strategy

**Unclear/TODO.** There is currently no automated QEMU command-flow test for
CHIPSEC in Heads CI. Before claiming CHIPSEC support, define and implement:

1. Packaging: stage CHIPSEC package + selected entrypoints into initrd.
2. Smoke: run minimal CHIPSEC command in booted QEMU image (non-driver path first).
3. Driver-backed tests: separate `chipsec-km`/kernel-module contract, kernel
   config/module support, `insmod` staging, and QEMU/hardware test matrix.
4. CI policy: opt-in job, artifact/log capture, known limits documented.

## Kernel driver (separate, draft module: `chipsec-km`)

`modules/chipsec-km` (CONFIG_CHIPSEC_KM=y, requires CONFIG_CHIPSEC/CPYTHON/LINUX):
- Builds `drivers/linux/chipsec.ko` from pinned chipsec commit against
  `$(build)/$(linux_dir)`.
- Strips and stages as `/lib/modules/chipsec.ko` in `modules.cpio` via generic
  `modules_files` staging.
- Load manually when needed: `insmod /lib/modules/chipsec.ko`.
- No auto-load; upstream `insmod.sh` PCR-measure behavior is not copied blindly.
- QEMU: build/staging/load wiring only; driver-backed CHIPSEC checks mostly
  hardware-specific. Automated QA TODO.
