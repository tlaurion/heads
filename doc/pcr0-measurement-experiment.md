# PCR 0 measurement experiment

This page records the state of the experiment to prove that the Intel ACM
measuring the Initial Boot Block into TPM PCR 0 is enough for measured boot,
with the root of trust in the bootblock. It cross references
[ibb-measurement.md](ibb-measurement.md) for the mechanism and
[tpm.md](tpm.md) for how Heads uses a PCR value, and does not restate them.

## Mission

The NovaCustom Meteor Lake boards `V540TU` and `V560TU` are the same
generation and are provisioned by 3mdeb. On units whose owner key hash is
fused into the platform fuses, the goal is to prove that the ACM measuring the
bootblock into PCR 0 yields a measured boot chain whose root of trust is the
bootblock itself, so a Heads build can carry the code that runs under that
root. 3mdeb's push for Boot Guard with fused keys is what makes the experiment
possible at all: without fusing there is no key for the vendor to sign a
policy against and no hardware measured path.

## Established

The Boot Guard chain, in the order the CPU walks it:

1. The platform fuses carry a Boot Guard profile. Only a profile that
   includes measurement lets the ACM extend PCR 0; a profile that only
   verifies runs the ACM and measures nothing.
2. At reset the CPU finds the Startup ACM in the FIT as type `0x02`. The
   Intel FIT specification's CPU processing rule is that a valid type 2
   entry is executed before the reset vector.
3. The signed Key Manifest and Boot Policy Manifest are present and their
   digest matches the exact image that was flashed. The Key Manifest must
   chain to the key hash in the fuses.
4. The ACM reads the measured bit from the signed policy, sets it, and
   extends PCR 0 with the IBB digest.
5. Coreboot reconstructs the event log on Meteor Lake and newer so that a
   replay matches the PCR 0 value.

A self built image cannot fill PCR 0 by itself on a fused unit. The vendor
manifests digest the vendor IBB, not a Heads IBB, so they do not describe the
image being booted. `INTEL_TXT_BIOSACM_FILE` only injects the raw ACM into the
FIT; Dasharo omits it and leaves the ACM to provisioning. Even with the ACM
present, a measurement needs a provisioned measuring profile and a manifest
signed by the key in the fuses.

The ME disable mode is not an input here. HAP and `AltMeDisable` are the same
descriptor bit, and that bit is unavailable when the descriptor is locked by
fusing. The `BP.HAP` field that reaches PCR 0 comes from the signed policy,
not from the runtime mode, so changing the ME mode does not turn measurement
on or off.

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
  not provisioned with a measuring profile, and the fix is provisioning, not
  a build change.

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

The Intel CBnT BWG is needed for the remaining question: what an unprovisioned
ACM does after it runs.
