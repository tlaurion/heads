# chipsec CPython profile (draft)

Additive CPython profile for CHIPSEC userspace on Heads. **Opt-in, draft**.

## Status

- **Implemented**: module-driven profile merge + per-board CPython smoke imports.
- **Not implemented**: CHIPSEC Python package staging, entrypoints/wrappers,
  kernel driver build/staging, automated QEMU boot/command-flow QA.

## Contract

- Selected by `modules/chipsec` via `chipsec_cpython_profiles += chipsec`.
- `CONFIG_CHIPSEC=y` requires `CONFIG_CPYTHON=y`.
- Keep-lists are closed allowlists; add entries only with traced CHIPSEC
  command/import evidence and smoke validation.

## Runtime additions over `base`

- stdlib: `csv`, `logging`, `concurrent`, `multiprocessing`, `plistlib`,
  `pprint`, `decimal` (and supporting stdlib pulled by profile keep-list).
- dynload: `_decimal`.
- `setup.local.disabled`: follows base/wyng disable posture; merge policy never
  disables `_hashlib`.

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

## Kernel driver (separate, future)

Full Linux helper functionality may require out-of-tree `chipsec.ko` built
against the exact Heads kernel (`build/<arch>/$(linux_dir)`) and loaded in
initrd. Treat as a separate module/contract; do not conflate with Python
userspace packaging.
