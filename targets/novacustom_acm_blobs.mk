# Targets for downloading the NovaCustom Meteor Lake V5x0 Startup ACM (SACM).
# The ACM is Intel signed proprietary firmware obtained from NovaCustom's
# published production image and is not committed here; this target runs the
# download/extract script. A plain Heads build does not need it (the MTL
# configs have CONFIG_INTEL_CBNT_SUPPORT not set). Add "novacustom_acm_blobs"
# to BOARD_TARGETS only for a CBnT measurement build. Fetching the ACM alone
# does not measure the IBB into PCR 0; that needs the provisioned measured
# Boot Guard profile and a manifest signed by the fused key. See the notes in
# blobs/novacustom_v5x0_mtl/v5x0_mtl_extract_acm.sh.

REQUIRED_BLOBS := \
    $(pwd)/blobs/novacustom_v5x0_mtl/MTL_BIOSAC_SIGNED.bin

# Make the Coreboot build depend on the required blob
$(build)/coreboot-$(CONFIG_COREBOOT_VERSION)/$(BOARD)/.build: $(REQUIRED_BLOBS)

# Rule to generate the required blob
$(REQUIRED_BLOBS):
	$(pwd)/blobs/novacustom_v5x0_mtl/v5x0_mtl_extract_acm.sh $(pwd)/blobs/novacustom_v5x0_mtl
