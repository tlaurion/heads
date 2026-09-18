# NovaCustom V5x0 (Meteor Lake) Startup ACM

The blob handled here is the Intel Startup ACM (SACM), the signed firmware run
at reset on a CBnT/Boot Guard board. It carries the IBB digest in the signed
Boot Policy Manifest and is what can measure the Initial Boot Block into TPM
PCR 0.

* `MTL_BIOSAC_SIGNED.bin` — Startup ACM, 132096 bytes, sha256
  `e9ddab7d96e5cbade4f79a5c5a4dfb5e2a6ebf819400d15398d949eb1ea569a6`.
  The V540TU and V560TU vendor images embed the identical ACM, so a single
  output is used; `-M` selects which vendor image is downloaded.

## Why this is not committed

The ACM is Intel signed proprietary firmware. It is obtained from NovaCustom's
own published production firmware image and is **not redistributed in this
repository**. A plain Heads source build does **not** need it: the NovaCustom
MTL configs have `CONFIG_INTEL_CBNT_SUPPORT` not set and point at zero-filled
placeholder manifests. The ACM is only needed for CBnT measurement builds or
for verifying a unit. See `doc/ibb-measurement.md`.

This recipe extracts **only** the Startup ACM (FIT type 0x02). It does not
sign, generate, download or write any Key Manifest or Boot Policy Manifest.

## Fetching the ACM is not enough to measure

An ACM in the FIT does not by itself produce a PCR 0 measurement:

* Commit `df4bcbc3180` (2022-06-16, OptiPlex TXT board): the BIOS ACM loaded
  and initialised, yet coreboot logged `TXT-STS: IBB not measured`.
* linuxboot/heads#1172, @miczyg1 on 2023-09-05: "Client TXT BIOS ACMs are not
  SACMs, thus the CPU does not run it, despite it is present in FIT. Server TXT
  ACMs are SACMs and are run at reset vector and those MEASURE IBB. … Unless
  you have a real server board, don't go with TXT to measure IBB, you have to
  provision BootGuard for it."

Measurement needs the measured Boot Guard profile provisioned in the platform —
the FPF, or CSE internal NV variables before End of Manufacturing. Where a
fused `BP.KEY` exists, it anchors the OEM chain: the Key Manifest (KM) signing
key is hashed and compared with `BP.KEY`, and only then is the KM's Boot Policy
Manifest (BPM) signing-key hash trusted. Intel documents `BP.KEY` as the FPF
register holding the KM signing-key digest, and states that Intel-provided
components are authenticated against a key stored in hardware "regardless if the
OEM KM is present or not"
(<https://www.intel.com/content/www/us/en/developer/articles/technical/software-security-guidance/resources/key-usage-in-integrated-firmware-images.html>).
Whether a fused key is required for, or authoritative on, an unfused platform is
not documented; no public report of an unfused unit running a Startup ACM with
self-signed manifests and measuring PCR 0 was found.

## Build prerequisites (clean checkout)

Building a CBnT measurement image needs three inputs this repository does not
fully carry by itself; only `cbnt.json` is committed.

* **`cbnt-prov` — required, NOT committed.** The build consumes it through
  `CONFIG_INTEL_CBNT_PROV_EXTERNAL_BIN=y` /
  `CONFIG_INTEL_CBNT_PROV_EXTERNAL_BIN_PATH` (see "cbnt-prov (external binary)"
  below). Expected artifact: sha256
  `b808741effbefd850d22f4ac3cd39c7117f176bc4c5093eaf44f9180d8763d71`,
  9,581,842 bytes, unstripped static x86-64 ELF, from
  `3rdparty/intel-sec-tools` @ `0031ac73447baeb197fb2d80e5fba2470716e76d`,
  built with go1.25.7 and `CGO_ENABLED=0`. Follow-up: provide it through a
  `modules/cbnt-prov` + `flake.*` requirement instead of an out-of-tree blob.
  A stale pre-patch `cbnt-prov` silently regresses the KM to SHA-256, so it
  must be rebuilt whenever patch 0004 or the pinned submodule changes.
* **`cbnt.json` — IS committed.** The BPM config-file source, consumed via
  `CONFIG_INTEL_CBNT_CBNT_PROV_CFG_FILE`.
* **`.acm.keys/{km,bpm}_key.pem` — NOT committed, deliberately ignored.** A
  locally generated test keypair; `blobs/novacustom_v5x0_mtl/.gitignore`
  ignores `.acm.*/` and nothing in the tree generates them, so a clean
  checkout cannot build until they exist. Regenerate with:

  ```console
  $ openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out blobs/novacustom_v5x0_mtl/.acm.keys/km_key.pem
  $ openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out blobs/novacustom_v5x0_mtl/.acm.keys/bpm_key.pem
  ```

  Observed: PKCS#8 unencrypted (`-----BEGIN PRIVATE KEY-----`), RSA-3072,
  mode 0600; `km_key.pem` 2484 B, `bpm_key.pem` 2488 B (the size varies by a
  few bytes with DER sign-byte padding).
* **Patch `0004` and the submodule.** The
  `0004-...preserve-km-pubkey-hash-alg` patch modifies
  `3rdparty/intel-sec-tools`; on a fresh coreboot fetch heads applies patches
  before checking out coreboot's submodules, so `3rdparty/intel-sec-tools`
  must be checked out before patch application (otherwise `0004` is skipped
  and the signed KM falls back to SHA-256).

## Usage

The vendor image is downloaded from `dl.3mdeb.com`, verified against the hash
NovaCustom publishes next to the `.rom`, and the ACM is extracted from the FIT
entry at address `0xffc40000` (file offset `0x1c40000`). The script is
idempotent: if the ACM already exists with the right hash it does nothing.

```console
$ ./blobs/novacustom_v5x0_mtl/v5x0_mtl_extract_acm.sh ./blobs/novacustom_v5x0_mtl
$ ./blobs/novacustom_v5x0_mtl/v5x0_mtl_extract_acm.sh -M v540tu /tmp/acm
```

Default model is `v560tu`; pass `-M v540tu` to extract from the 14-inch image.

The make target `targets/novacustom_acm_blobs.mk` runs the script. It is not
wired into any board build (the MTL configs do not enable CBnT); add
`novacustom_acm_blobs` to a board's `BOARD_TARGETS` only for a measurement
build.

## cbnt-prov (external binary)

The CBnT manifest steps (`km-gen`, `bpm-gen`, `km-sign`, `bpm-sign`) are driven
by `cbnt-prov`, a Go tool from `3rdparty/intel-sec-tools`. coreboot builds it
with `go build` (`src/security/intel/cbnt/Makefile.mk:38-41`), but the
reproducible Heads dev image carries no Go toolchain, so a clean build fails
with `go: command not found`.

coreboot supports an external binary for exactly this offline case:
`CONFIG_INTEL_CBNT_PROV_EXTERNAL_BIN=y` plus
`CONFIG_INTEL_CBNT_PROV_EXTERNAL_BIN_PATH` make the build copy a supplied
binary instead of invoking `go` (`src/security/intel/cbnt/Makefile.mk:37-45`,
declared in `src/security/intel/cbnt/Kconfig:96-108`).

`cbnt-prov` here is that binary. It is a static x86-64 build from the
coreboot-pinned `3rdparty/intel-sec-tools` submodule
(`0031ac73447baeb197fb2d80e5fba2470716e76d`), built with `CGO_ENABLED=0` so it
runs in the build container regardless of libc. Both ACM configs point
`CONFIG_INTEL_CBNT_PROV_EXTERNAL_BIN_PATH` at it through `@BLOB_DIR@`. sha256
`b808741effbefd850d22f4ac3cd39c7117f176bc4c5093eaf44f9180d8763d71`, also
listed in `hashes.txt`. `intel-sec-tools` is BSD 3-Clause licensed.

Heads patch
`patches/coreboot-dasharo_v56-unreleased/0004-security-intel-cbnt-preserve-km-pubkey-hash-alg.patch`
is applied to the submodule before this build. It stops `km-sign` from
overwriting `KmPubKeyHashAlg` with the (SHA-256 default) signature hash, so a
KM generated with `--pkhashalg=SHA384` (coreboot patch 0003) stays SHA-384
after signing (byte `0x0c` at KM+0x14 instead of `0x0b`). The binary above was
rebuilt from that patched source; **a stale pre-patch `cbnt-prov` silently
produces a SHA-256 KM again**, so rebuild this blob whenever patch 0004 (or the
pinned submodule) changes.

Rebuild it with the module cache Go toolchain if the pinned submodule moves:

```console
$ cd build/x86/coreboot-dasharo_v56/3rdparty/intel-sec-tools
$ CGO_ENABLED=0 /home/user/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.7.linux-amd64/bin/go \
    build -o <repo>/blobs/novacustom_v5x0_mtl/cbnt-prov \
    cmd/cbnt-prov/main.go cmd/cbnt-prov/cmd.go
```

Unlike the ACM, this binary is not proprietary Intel firmware; supplying it as
a blob is what lets a clean checkout build without a Go toolchain. Whether it
is committed to the tree or fetched at build time is an open decision.

## Provenance

The offset was verified with `cbnt-prov fit-show` / `cbnt-prov export-acm`
from `3rdparty/intel-sec-tools`, which reports the Startup ACM FIT entry
(type 0x02) at `0xffc40000` and exports the same 132096 bytes with sha256
`e9ddab7d…69a6` (header date 2024-05-01, TxtSVN 2, SeSVN 5). This script
reproduces that extraction with a documented `dd` because `cbnt-prov` is a Go
tool the Heads dev image does not carry a Go toolchain for. See
"cbnt-prov (external binary)" below for how the build gets one.

| Model  | Vendor image                                      | Vendor sha256 |
|--------|---------------------------------------------------|---------------|
| V540TU | `novacustom_v54x_mtl_igpu_v1.0.1_btg_prod.rom`    | `e915ed1eae8b7b91a7a94ad7a75d57a4a077c0e7c6379234755788ca72fb1cd9` |
| V560TU | `novacustom_v56x_mtl_igpu_v1.0.1_btg_prod.rom`    | `0c66f864685e5216ff9219c9ff01adf54bb31022742ee19078aa083b065d52c6` |

See `hashes.txt` for the full checksum list.
