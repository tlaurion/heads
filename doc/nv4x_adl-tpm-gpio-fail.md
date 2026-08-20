# nv4x_adl TPM GPIO reset (PLTRST#) -- investigation conclusion

## Problem
The NovaCustom NV4x Alder Lake board (nv40pz) is vulnerable to the "TPM GPIO
fail" attack (https://mkukri.xyz/2024/06/01/tpm-gpio-fail.html): the PLTRST#
pad (GPP_B13) configuration is left unlocked, so software running after the
firmware can switch it to GPIO mode and pulse it, resetting a discrete TPM
while the host keeps running and clearing the PCRs.

Confirmed on Dasharo v0.9.3; tracked as Dasharo issue #1908 and
tlaurion/tpm-gpio-fail#1.

## The released fix: Dasharo/coreboot PR #959 ("Pltrst lock v2")
8 commits by Filip Lewinski (3mdeb), all `Upstream-Status: Pending`, head
c816192fa0ad457495060839a1f59f5615c0a2e0, base branch `dasharo`. It locks
GPP_B13 from the SMM finalize handler via a new `soc_gpio_lock_config()`
hook and a new Kconfig `SOC_INTEL_COMMON_BLOCK_GPIO_LOCK_PLTRST_PAD`.

## Key findings
1. Parent is divergent, not shared: the pinned tag `novacustom_nv4x_adl_v1.8.0`
   (281a7fec) and PR #959's base (7c16974602) share only a Dec 2024 ancestor;
   the `dasharo` branch was rebased onto newer upstream coreboot. There is no
   packable linear "dependence". All 8 PR commits apply cleanly in sequence
   against 281a7fec.
2. The fork already contains the merged upstream GPIO-lock infrastructure
   (PAD_CFG_NF_LOCK macro, gpio_lock_pad/gpio_lock_pads, SBI/PCR lock helpers,
   pad_cfg_lock_offset, SOC_INTEL_COMMON_BLOCK_GPIO_LOCK_USING_SBI).
3. PR #959's Kconfig option `depends on INTEL_CHIPSET_LOCKDOWN`. The Heads
   board config has INTEL_CHIPSET_LOCKDOWN disabled.

## Conclusion
INTEL_CHIPSET_LOCKDOWN is not compatible with Heads: it locks down SPI flash
at coreboot finalize (FLOCKDN + BIOS-region write-protect), which breaks
Heads' internal flashprog reflash and hardware reflashing/testing. Heads
deliberately keeps coreboot lockdown off and performs its own lockdown (the
io386 lock) right before kexec.

Therefore the full PR #959 patchset (which depends on INTEL_CHIPSET_LOCKDOWN)
is not suitable for Heads as-is. The upstream-aligned, Heads-compatible fix is
a single board-table change: `PAD_CFG_NF_LOCK(GPP_B13, NONE, NF1, LOCK_CONFIG)`
in src/mainboard/clevo/adl-p/variants/nv40pz/gpio.c. This locks only the
PLTRST# pad (no SPI impact, no lockdown) and matches the direction upstream
coreboot itself took (moving away from soc_gpio_lock_config toward board-table
PAD_CFG_NF_LOCK).

## Open items / TODO
- [ ] Revert the INTEL_CHIPSET_LOCKDOWN enable and remove the 8 PR #959 patches
      from the working tree (staged experimentally; the build passed but the
      lockdown approach is wrong for Heads).
- [ ] Restore the single PAD_CFG_NF_LOCK patch under patches/coreboot-dasharo_nv4x/.
- [ ] Runtime-verify the fix: boot under QEMU and confirm PADCFGLOCK bit 13 is
      set (i.e. the non-SMM SBI lock actually takes effect on ADL). PR #959's
      author claims "PADCFGLOCK writes are only honoured when they carry the
      SMM security attribute", so this must not be assumed.
- [ ] Confirm whether the ns50pu variant (same clevo/adl-p baseboard) shares the
      same unlocked GPP_B13 and decide if it needs the same lock.
