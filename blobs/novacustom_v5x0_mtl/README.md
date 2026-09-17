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

Measurement needs the measured Boot Guard profile provisioned in the platform
fuses plus a Boot Policy Manifest signed by the key fused into the FPF.

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

## Provenance

The offset was verified with `cbnt-prov fit-show` / `cbnt-prov export-acm`
from `3rdparty/intel-sec-tools`, which reports the Startup ACM FIT entry
(type 0x02) at `0xffc40000` and exports the same 132096 bytes with sha256
`e9ddab7d…69a6` (header date 2024-05-01, TxtSVN 2, SeSVN 5). This script
reproduces that extraction with a documented `dd` because `cbnt-prov` is a Go
tool the Heads build does not build.

| Model  | Vendor image                                      | Vendor sha256 |
|--------|---------------------------------------------------|---------------|
| V540TU | `novacustom_v54x_mtl_igpu_v1.0.1_btg_prod.rom`    | `e915ed1eae8b7b91a7a94ad7a75d57a4a077c0e7c6379234755788ca72fb1cd9` |
| V560TU | `novacustom_v56x_mtl_igpu_v1.0.1_btg_prod.rom`    | `0c66f864685e5216ff9219c9ff01adf54bb31022742ee19078aa083b065d52c6` |

See `hashes.txt` for the full checksum list.
