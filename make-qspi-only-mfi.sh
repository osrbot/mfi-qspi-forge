#!/usr/bin/env bash

set -euo pipefail

usage()
{
	echo "Usage: $0 [--fast] [source-mfi-dir] [output-dir]"
	echo
	echo "Create a QSPI-only copy of an existing Seeed/NVIDIA MFI package."
	echo "The source package is never modified."
	echo
	echo "  --fast  Skip the 64 MiB full-chip erase during QSPI flashing."
	echo "          Use only for blank or controlled-production devices."
}

if [[ "${1:-}" = "-h" || "${1:-}" = "--help" ]]; then
	usage
	exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fast_mode=0

if [[ "${1:-}" = "--fast" ]]; then
	fast_mode=1
	shift
fi

source_dir="${1:-${script_dir}/mfi_recomputer-orin-super-j401}"
mode_suffix=""
[[ "${fast_mode}" -eq 1 ]] && mode_suffix="-fast"
output_dir="${2:-${source_dir}-qspi-only${mode_suffix}}"

if [[ ! -f "${source_dir}/tools/kernel_flash/l4t_initrd_flash.sh" ]]; then
	echo "Error: ${source_dir} is not an MFI package" >&2
	exit 1
fi

if [[ -e "${output_dir}" ]]; then
	echo "Error: output path already exists: ${output_dir}" >&2
	exit 1
fi

mkdir -p "${output_dir}"

# The external flash index is what makes the target-side flash script write
# the SSD and rootfs. Omitting the complete external image directory keeps the
# vendor scripts unchanged while leaving QSPI as the only flash target.
tar -C "${source_dir}" \
	--exclude='./tools/kernel_flash/images/external' \
	--exclude='./tools/kernel_flash/tmp' \
	--exclude='./initrdlog' \
	--exclude='./temp_initrdflash' \
	-cf - . | tar -C "${output_dir}" -xf -

patch_file="${script_dir}/assets/qspi-skip-full-erase.patch"
if ! patch -s -d "${output_dir}" -p1 < "${patch_file}"; then
	echo "Error: failed to enable QSPI erase-mode selection" >&2
	exit 1
fi

if [[ "${fast_mode}" -eq 1 ]]; then
	touch "${output_dir}/tools/kernel_flash/images/QSPI_SKIP_FULL_ERASE"
fi

erase_mode_text="Full"
[[ "${fast_mode}" -eq 1 ]] && erase_mode_text="Fast"

cat > "${output_dir}/QSPI_ONLY.txt" <<EOF
This is a QSPI-only derivative of the original MFI package.

Run from this directory:

  sudo ./tools/kernel_flash/l4t_initrd_flash.sh \\
    --flash-only --massflash 1 --network usb0 --showlogs

The external/SSD flash index is intentionally absent, so the vendor scripts
flash QSPI only and do not write the SSD or rootfs.

QSPI erase mode: ${erase_mode_text}

Fast mode skips the full-chip erase and is intended only for blank or
controlled-production QSPI devices. Stale data outside written partitions is
not cleaned. Use Full mode for reused or recovery devices.
EOF

echo "QSPI-only MFI created at: ${output_dir}"
du -sh "${output_dir}"
