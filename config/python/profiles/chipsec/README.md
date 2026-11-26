# chipsec CPython profile

Additive CPython profile for the CHIPSEC userspace package on Heads. Opt-in
(`CONFIG_CHIPSEC=y`), selected by `modules/chipsec`.

## Implemented packaging

- `modules/chipsec` clones the pinned CHIPSEC source (PR2945 test commit
  `30e5aa61544ea69c25163415ecca1fba426a283d`, which carries
  `common.pltrst_gpio_lock`) and stages the **full upstream `chipsec/` package
  plus `chipsec_main.py` and `chipsec_util.py`** into
  `/lib/python$(cpython_mm)/site-packages` via `chipsec_tools`/tools.cpio.
- The native layout is preserved deliberately: `chipsec_main.py` looks for
  `chipsec/` as its sibling and reads `chipsec/VERSION` (2.0.10) and
  `chipsec/options/cmd_options.ini` relative to its own directory. Flattening
  the package would break those paths.
- `drivers/`, `*.ko`, `setup.py`, the manual, `tests/`, the host `chipsec_tools/`
  tree and other host-only build artifacts are **not** staged.
- `modules/chipsec.requires` enables `CONFIG_CPYTHON` and `CONFIG_OPENSSL`.
  `_hashlib` (hashlib's OpenSSL backend) is enabled in this profile's
  `Setup.local` and its `libcrypto` dependency is owned here via
  `chipsec_cpython_depends := openssl`, so chipsec-only boards are self-contained.

## Wrapper

`chipsec_configure` generates an executable `chipsec-wrapper` in the module
build dir:

```sh
#!/bin/sh
export PYTHONDONTWRITEBYTECODE=1
exec /bin/python3 /lib/python3.13/site-packages/chipsec_main.py "$@"
```

It is staged through `chipsec_output` to `/bin/chipsec-wrapper`, and `/bin/chipsec`
is an explicit relative symlink to it, following the wyng-backup symlink pattern
(the bin staging flattens by basename and cannot create links itself). The
`make BOARD=... chipsec` target remains a clone/configure/no-op build.

## Real CLI smoke

`chipsec_cpython_smoke_pythonpath` points at the chipsec source tree and the
smoke imports are `chipsec chipsec_main chipsec_util` plus the traced capability
set (`hashlib _hashlib argparse configparser heapq locale platform uuid
xml.etree.ElementTree`). `make BOARD=... cpython_test` therefore imports the
real package through the target interpreter, not a stub.

The keep-lists are closed allowlists derived from tracing
`chipsec_main.py --help` and `chipsec_main.py -lm -nb` on the target Python:

- stdlib additions: `argparse`, `configparser`, `hashlib`, `heapq`, `locale`,
  `platform`, `uuid`, `json`, `gettext`, `glob`, `shutil`, `runpy`, `pkgutil`,
  `bisect`, `fnmatch` (plus the XML/helper closure).
- dynload additions: `_hashlib`, `_elementtree`, `mmap`, `resource`, `_heapq`,
  `_bisect`, `_blake2` (plus the pre-existing `_csv`/`pyexpat`/... set).
- Optional `cryptography`, `brotli`, `_lzma`, `_bz2`, `_uuid` remain absent:
  their imports are guarded/optional and are not reached by the safe CLI paths.

Two QEMU command-flow plans exercise the staged wrapper in a booted QA ROM:
`config/qemu/qemu-coreboot-fbwhiptail-tpm2-cpython-chipsec.smoke` runs
`/bin/chipsec --help` (reports version 2.0.10) and `/bin/chipsec -lm -nb`
(lists `common.pltrst_gpio_lock`); the combined `...-wyng-chipsec.smoke` adds
the Wyng and zstd/Cryptodome checks. No insmod, hardware, or driver commands.

## Remaining limits

- `chipsec.ko` remains a separate opt-in module (`modules/chipsec-km`,
  `CONFIG_CHIPSEC_KM=y`). It builds against the Heads kernel tree and stages
  `/lib/modules/chipsec.ko`, but is never auto-loaded. A separate QEMU check
  verified `insmod` return code 0 and `/dev/chipsec` creation; driver-backed
  security checks remain hardware-specific and unverified.
- The safe QEMU smoke proves package/wrapper staging and non-driver CLI
  startup only; it does not execute CHIPSEC security modules or touch devices.

## Validation

```sh
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-chipsec chipsec
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-chipsec all cpython_test qemu_smoke
HEADS_DISABLE_USB=1 ./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2-cpython-wyng-chipsec all cpython_test qemu_smoke
```
