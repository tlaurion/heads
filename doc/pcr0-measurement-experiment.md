# PCR 0 measurement experiment

This page records the state of the experiment to prove that the Intel ACM
measuring the Initial Boot Block into TPM PCR 0 is enough for measured boot,
with the root of trust in the bootblock. The offline work has since shown
that the ACM alone cannot measure and that the variant built for the test has
no IBB to measure, so the page records what is established offline and what
the hardware test still has to probe. It cross references
[ibb-measurement.md](ibb-measurement.md) for the mechanism and
[tpm.md](tpm.md) for how Heads uses a PCR value, and does not restate them.

## Mission

The NovaCustom Meteor Lake boards `V540TU` and `V560TU` are the same
generation. The experiment runs on an unfused unit: no owner key hash is in
the platform fuses, so no provisioned policy describes the image. The goal is
to prove that the ACM measuring the bootblock into PCR 0 yields a measured
boot chain whose root of trust is the bootblock itself, so a Heads build can
carry the code that runs under that root. The ACM is authenticated by the CPU
against Intel's keys, which does not depend on fusing; the fuses and the OEM
key govern verification of the manifests instead.

## Established

The Boot Guard chain, in the order the CPU walks it:

1. In the provisioned case the platform fuses carry a Boot Guard profile.
   Only a profile that includes measurement lets the ACM extend PCR 0; a
   profile that only verifies runs the ACM and measures nothing. An unfused
   platform has no such profile.
2. At reset the CPU finds the Startup ACM in the FIT as type `0x02`. The
   Intel FIT specification's CPU processing rule is that a valid type 2
   entry is executed at reset with no provisioning precondition. Execution
   and measurement are separate: the ACM runs unprovisioned, but it only
   measures when the provisioned policy sets the measured bit.
3. A signed Key Manifest and Boot Policy Manifest are present. The BPM digest
   list must match the exact flashed image, so a placeholder manifest cannot
   describe it. Where a fused hash exists it governs verification of the Key
   Manifest and Boot Policy Manifest; it does not govern the ACM, which the
   CPU authenticates against Intel's keys.
4. The ACM reads the measured bit from the signed policy, sets it, and
   extends PCR 0 with the IBB digest. On CBnT the IBB digest list comes from
   the Boot Policy Manifest and covers `bootblock`, `fallback/verstage` and
   `fspt.bin`; coreboot deliberately does not publish IBB entries as FIT
   type 7 on CBnT, which is a legacy Intel TXT behavior. An image with an
   ACM but no BPM has no IBB, so there is nothing to measure and the run is
   void.
5. Coreboot reconstructs the event log on Meteor Lake and newer so that a
   replay matches the PCR 0 value.

A self built image cannot fill PCR 0 by itself. The vendor manifests digest
the vendor IBB, not a Heads IBB, so they do not describe the image being
booted. `INTEL_TXT_BIOSACM_FILE` only injects the raw ACM into the FIT;
Dasharo omits it and leaves the ACM to provisioning. For this test we generate
a self signed Key Manifest and Boot Policy Manifest whose only role is to
define the IBB, a digest list over `bootblock`, `fallback/verstage` and
`fspt.bin`. The test then determines whether the ACM on an unfused platform
accepts manifests that chain to no fused hash, which is not documented. A
production manifest set would have to be signed by whoever owns the platform's
key.

The ME disable mode is irrelevant here. HAP and `AltMeDisable` are the same
descriptor bit renamed across ME generations, and setting it needs a
writeable descriptor, so it is unavailable on a fused unit, where soft
disable over HECI is the mode. The `BP.HAP` field that reaches PCR 0 comes
from the signed policy, not from the runtime mode, so switching modes does
not change the measured value.

The earlier evidence is in [ibb-measurement.md](ibb-measurement.md),
`linuxboot/heads#1172`, and commit `df4bcbc3180`: an ACM load and initialise
was observed on a client machine while the IBB was reported not measured.
That is the observation this experiment sets out to explain on these boards.

## The deciding observable

The diagnostic forks on one thing: whether the ACM ran at all.

* If the SCRTM status is zero and the platform reports no Boot Guard
  capability, then the FIT specification says the type 2 entry should have
  run. An ACM that was present and did not run is a defect to investigate in
  the FIT entry or in ACM authentication.
* If the ACM ran but the measured bit is clear, then the absence of a PCR 0
  measurement is the documented expected outcome. It means the platform is
  not provisioned with a measuring profile, and the fix is provisioning where
  the platform can be provisioned, not a build change.

## What we learned

The offline work narrowed the problem before any hardware test, and some of
the original assumptions were wrong.

The ACM alone cannot measure. Execution follows the FIT: Intel's specification
says a valid type 2 entry is executed at reset with no provisioning
precondition. Measurement is separate and is gated on the measured bit in the
provisioned policy, reported as `CBNT_BP_TYPE_M` in the ACM policy status.
Execution without provisioning is expected and produces no PCR 0 value. This
is the client observation recorded in `linuxboot/heads#1172` and commit
`df4bcbc3180`.

On CBnT the IBB is defined by the Boot Policy Manifest, not by the FIT. The
digest list covers `bootblock`, `fallback/verstage` and `fspt.bin`, and
coreboot deliberately does not publish IBB entries as FIT type 7 on CBnT, a
legacy Intel TXT behavior. The consequence voids the first image: an image
with an ACM but no BPM has no IBB, so there is nothing to measure. The offline
check with `cbnt-prov fit-show` lists the ACM (type `0x02`) and no Key Manifest
(`0x0b`) or Boot Policy Manifest (`0x0c`).

The ACM is authenticated by the CPU against Intel's keys, and that does not
depend on fusing. The fuses and the OEM key govern verification of the Key
Manifest and Boot Policy Manifest instead. The test therefore does not require
manifests chained to a fused key. We generate a self signed Key Manifest and
Boot Policy Manifest whose role is to define the IBB, and the hardware test
also determines whether the ACM on this unfused platform accepts manifests
that chain to no fused hash, which is not documented. Production manifests
would still have to be signed by whoever owns the platform's key.

The ME disable mode is irrelevant here, as set out above.

Offline verification found the variant image
`heads-novacustom-v560tu-acm-202609172007-v0.2.1-3223-gc4ffb62.rom` (sha256
`446eadf9...`) carries the Startup ACM at `0xff980000`, file offset
`0x1980000`. The extracted ACM matches the extractor output at 132096 bytes
(sha256 `e9ddab7d...`), and the base image has no ACM at all. One observation
to keep as a suspect: `fit-show` reports the ACM entry FIT checksum as
invalid. That may be a tool artifact, but it would also explain an ACM that
never runs.

Flashkeeper (`linuxboot/flashkeeper`) is the independent physical layer. It is
a hardware SPI interposer that uses the flash write protect and block protect
bits with out of band state validation. It needs no Boot Guard, no fuses and
no TPM, and it produces no measurements, so it complements the measured chain
rather than replacing any part of it.

## What exists on branches

All four branches are pushed to `tlaurion`, none has a pull request open, and
all commits are signed.

| Branch | Tip | What it adds |
| --- | --- | --- |
| `boards/novacustom-v5x0-acm` | `199f93091dd` | ACM variants for both boards, EC model mapping, and the coreboot patch |
| `blobs/novacustom-v5x0-mtl-acm` | `8a02db5b541` | ACM extractor that writes `blobs/novacustom_v5x0_mtl/MTL_BIOSAC_SIGNED.bin` |
| `pcr0-diag` | `a5940465ad0` | `scripts/pcr0-diag.sh`, the read only diagnostic |
| `doc/ibb-acm-client-startup` | `a038b95da42` | The scoped explanation of the client ACM claim |

The `boards/novacustom-v5x0-acm` build produced
`build/x86/novacustom-v560tu-acm/heads-novacustom-v560tu-acm-202609172007-v0.2.1-3223-gc4ffb62.rom`,
33554432 bytes, sha256
`446eadf93ff34273c83df1c386d8fe3892535df5feff04a2f1a960862aee81d4`.

## The build fix worth upstreaming

The Dasharo coreboot fork's `measurement.c` embeds a struct whose last member
is a flexible array inside another struct. GCC 14 and above reject that layout.
The local patch adds a fixed size header struct for the two deprecated fields
that nothing reads, which restores the build without changing what is
measured. The fix belongs upstream in the Dasharo fork, not in Heads, and
lives at
`patches/coreboot-dasharo_v56-unreleased/0001-security-intel-cbnt-Fix-flexible-array-member-nesting.patch`.
The variant also needed EC model mappings in `modules/dasharo-ec`. The base
`V540TU` and `V560TU` boards and their coreboot configs are untouched by
design.

## How to run the test

1. Flash the image above.
2. Build `pcr0tool` from `3rdparty/intel-sec-tools/cmd/pcr0tool`.
3. Boot with `iomem=relaxed intel_iommu=on`.
4. Run `scripts/pcr0-diag.sh`.
5. Read the four facts it prints: the measured bit, whether PCR 0 is non
   zero, whether the Boot Guard or IBB entry is in the event log, and whether
   the replay matches.

WARNING: flashing a build like this onto a unit that is already fused with an
enforcing profile can stop it booting.

## Open questions

Only the vendor can answer these:

* The fuse state and profile of each unit.
* Whether the Key Manifest and Boot Policy Manifest in the published images
  chain to the key hash fused into production units.
* Which profiles measure.
* Whether the vendor will sign a Boot Policy Manifest over a Heads IBB.

The Intel CBnT BWG is needed for the remaining question: whether an
unprovisioned ACM accepts a Key Manifest and Boot Policy Manifest that chain
to no fused hash.
