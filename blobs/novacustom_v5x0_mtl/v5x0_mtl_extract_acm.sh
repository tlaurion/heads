#!/usr/bin/env bash
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

# Download the Intel Startup ACM (SACM) needed for CBnT/Boot Guard measured
# boot on the NovaCustom Meteor Lake V5x0 boards and extract it from the
# vendor's own published production firmware image.
#
# The ACM is Intel signed proprietary firmware obtained from the vendor image.
# It is NOT redistributed in this repository and is not committed here; this
# script downloads the vendor image and extracts the ACM locally. It writes only
# inside the blob directory and never touches flash or platform fuses.
#
# A plain Heads source build does NOT need the ACM. The NovaCustom MTL configs
# have CONFIG_INTEL_CBNT_SUPPORT not set and point at zero-filled placeholder
# manifests; the ACM is only needed for CBnT measurement builds or for
# verifying a unit. See doc/ibb-measurement.md.
#
# This script extracts only the Startup ACM (FIT type 0x02). It does not sign,
# generate, download or write any Key Manifest or Boot Policy Manifest.
#
# Fetching the ACM is not by itself enough to measure the IBB into PCR 0:
#
#   * linuxboot/heads#1172, @miczyg1 on 2023-09-05: on client silicon a TXT
#     BIOS ACM is not a Startup ACM, so the CPU does not run it even when it is
#     present in the FIT. Server TXT ACMs are SACMs, are run at the reset vector
#     and do measure the IBB; client boards need Boot Guard provisioned instead.
#   * Commit df4bcbc3180 (2022-06-16, OptiPlex TXT board) reports the BIOS ACM
#     loaded and initialised, yet coreboot logged "TXT-STS: IBB not measured",
#     so an ACM in the FIT alone does not produce a PCR 0 measurement.
#
# The ACM alone cannot fill PCR 0. Measurement needs the measured Boot Guard
# profile provisioned in the platform fuses plus a Boot Policy Manifest signed
# by the key fused into the FPF.
#
# Provenance of the file offset:
#   `cbnt-prov fit-show` (3rdparty/intel-sec-tools/cmd/cbnt-prov) reports a
#   startup_ACM_entry (FIT type 0x02) at address 0xffc40000, i.e. file offset
#   0x1c40000 in the 32 MiB image. `cbnt-prov export-acm` exports the same
#   132096 bytes (header size field 0x8100 dwords) with sha256
#   e9ddab7d96e5cbade4f79a5c5a4dfb5e2a6ebf819400d15398d949eb1ea569a6
#   (header date 2024-05-01, TxtSVN 2, SeSVN 5). The same bytes are extracted
#   here with dd at that verified offset: dd is used rather than cbnt-prov
#   because cbnt-prov is a Go tool the Heads build does not build, and the blob
#   recipes here use coreboot utilities or plain dd for extraction.
#
# Both published V5x0 MTL images embed the identical Startup ACM, so a single
# output is produced. -M selects which vendor image is downloaded. The image
# hashes are the vendor's own published checksums (dl.3mdeb.com release notes /
# security page) and each was confirmed by hashing the downloaded image:
#   V540TU: e915ed1eae8b7b91a7a94ad7a75d57a4a077c0e7c6379234755788ca72fb1cd9
#   V560TU: 0c66f864685e5216ff9219c9ff01adf54bb31022742ee19078aa083b065d52c6

# Startup ACM: FIT type 0x02 at address 0xffc40000, file offset 0x1c40000.
# 0x1c40000 and ACM_SIZE are both 1024-aligned, so dd can use bs=1024.
ACM_OFFSET=$((0x1c40000))
ACM_SIZE=132096
ACM_BLOB_HASH=e9ddab7d96e5cbade4f79a5c5a4dfb5e2a6ebf819400d15398d949eb1ea569a6
ACM_NAME=MTL_BIOSAC_SIGNED.bin

# The two vendor images carry the same signed ACM; the model only picks the
# source image. Hashes are vendor published and independently verified.
V540TU_IMAGE_HASH=e915ed1eae8b7b91a7a94ad7a75d57a4a077c0e7c6379234755788ca72fb1cd9
V560TU_IMAGE_HASH=0c66f864685e5216ff9219c9ff01adf54bb31022742ee19078aa083b065d52c6

usage() {
	echo -n \
		"Usage: $(basename "$0") [-M v540tu|v560tu] [output_directory]
Download the NovaCustom Meteor Lake V5x0 production firmware image and extract
the Intel Startup ACM (SACM) used for CBnT/Boot Guard measured boot. Defaults
to the V560TU model. The image is verified against the vendor published hash;
only the Startup ACM is written out. No Key Manifest or Boot Policy Manifest is
downloaded or written. The ACM is Intel signed proprietary firmware and is not
redistributed by this repository.
"
}

usage_err() {
	echo "$1"
	usage
	exit 1
}

parse_params() {
	local model_arg=""
	while getopts ":M:" opt; do
		case $opt in
		M)
			model_arg="$OPTARG"
			;;
		?)
			usage_err "Invalid Option: -$OPTARG"
			;;
		esac
	done
	shift $((OPTIND - 1))

	model="${model_arg:-v560tu}"
	case "$model" in
	v540tu)
		image_filename="novacustom_v54x_mtl_igpu_v1.0.1_btg_prod.rom"
		image_hash="$V540TU_IMAGE_HASH"
		image_url="https://dl.3mdeb.com/open-source-firmware/Dasharo/novacustom_v5x0_mtl/novacustom_mtl_igpu/novacustom_v540tu_mtl/uefi/v1.0.1/${image_filename}"
		;;
	v560tu)
		image_filename="novacustom_v56x_mtl_igpu_v1.0.1_btg_prod.rom"
		image_hash="$V560TU_IMAGE_HASH"
		image_url="https://dl.3mdeb.com/open-source-firmware/Dasharo/novacustom_v5x0_mtl/novacustom_mtl_igpu/novacustom_v560tu_mtl/uefi/v1.0.1/${image_filename}"
		;;
	*)
		usage_err "Unknown model '$model'. Expected v540tu or v560tu."
		;;
	esac

	output_dir_arg="${1:-./}"
	mkdir -p "$output_dir_arg" || usage_err "Could not create output dir '$output_dir_arg'"
	output_dir="$(realpath "$output_dir_arg")"
	if [[ ! -d "${output_dir}" ]]; then
		usage_err "No valid output dir found"
	fi
	acm="${output_dir}/${ACM_NAME}"
}

download_and_extract() {
	local image_path="${output_dir}/${image_filename}"

	# Reuse an already-downloaded vendor image if it is present and correct;
	# otherwise fetch it into the scratch dir (inside the blob dir, so nothing
	# is written outside it).
	if ! check_outputs "${image_hash} ${image_path}" >/dev/null 2>&1; then
		image_path="${tmpdir}/${image_filename}"
		echo "Downloading ${image_url}"
		curl -A "$user_agent" -s -o "$image_path" "$image_url" \
			|| { echo "ERROR: download failed for ${image_url}"; exit 1; }
	fi

	# Verify the vendor image before trusting any offset inside it.
	chk_sha256sum "$image_hash" "$image_path"

	# Extract the Startup ACM at the verified FIT address. Only the ACM is
	# written out; no Key Manifest or Boot Policy Manifest is exported.
	echo "### Extracting Startup ACM at file offset 0x1c40000"
	dd if="$image_path" of="${tmpdir}/${ACM_NAME}" bs=1024 \
		skip=$((ACM_OFFSET / 1024)) count=$((ACM_SIZE / 1024)) status=none \
		|| { echo "ERROR: dd failed to extract the Startup ACM"; exit 1; }

	mv "${tmpdir}/${ACM_NAME}" "$acm" \
		|| { echo "ERROR: failed to move ACM to $acm"; exit 1; }
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	if [[ "${1:-}" == "--help" ]]; then
		usage
		exit 0
	fi

	parse_params "$@"

	user_agent="Mozilla/5.0 (Windows NT 10.0; rv:91.0) Gecko/20100101 Firefox/91.0"

	# Idempotent: skip everything if the ACM already exists with the right hash.
	check_outputs "${ACM_BLOB_HASH} ${acm}" && { echo "All outputs match. Nothing to do."; exit 0; }

	echo "Writing Startup ACM for ${model} to ${acm}"

	# Scratch space inside the blob directory; removed on exit.
	tmpdir="$(mktemp -d "${output_dir}/.acm.XXXXXX")" \
		|| { echo "ERROR: could not create scratch dir in ${output_dir}"; exit 1; }
	trap 'rm -rf "$tmpdir"' EXIT

	download_and_extract

	check_outputs "${ACM_BLOB_HASH} ${acm}" || exit 1
fi
