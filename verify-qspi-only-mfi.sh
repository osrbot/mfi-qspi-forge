#!/usr/bin/env bash

set -euo pipefail

usage()
{
	echo "Usage: $0 [qspi-only-mfi-dir]"
}

if [[ "${1:-}" = "-h" || "${1:-}" = "--help" ]]; then
	usage
	exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_dir="${1:-${script_dir}/mfi_recomputer-orin-super-j401-qspi-only}"
images_dir="${package_dir}/tools/kernel_flash/images"
internal_index="${images_dir}/internal/flash.idx"
target_script="${package_dir}/tools/kernel_flash/images/l4t_flash_from_kernel.sh"

fail()
{
	echo "Error: $*" >&2
	exit 1
}

[[ -d "${package_dir}" ]] || fail "package directory not found: ${package_dir}"
[[ -f "${package_dir}/tools/kernel_flash/l4t_initrd_flash.sh" ]] || \
	fail "l4t_initrd_flash.sh not found"
[[ -f "${package_dir}/bootloader/boot0.img" ]] || \
	fail "bootloader/boot0.img not found"
[[ -f "${internal_index}" ]] || fail "internal flash.idx not found"
[[ ! -e "${images_dir}/external/flash.idx" ]] || \
	fail "external flash.idx is present; this package can flash SSD/rootfs"

qspi_mode="full"
if [[ -f "${images_dir}/QSPI_SKIP_FULL_ERASE" ]]; then
	qspi_mode="fast"
	grep -q 'QSPI_SKIP_FULL_ERASE' "${target_script}" || \
		fail "fast marker exists but the target script is not patched"
fi

non_qspi_entries="$(grep -vE ', *3:0:' "${internal_index}" || true)"
[[ -z "${non_qspi_entries}" ]] || fail \
	"internal flash.idx contains non-QSPI entries:\n${non_qspi_entries}"

missing=()
hash_errors=()
while IFS= read -r entry; do
	file_name="$(echo "${entry}" | cut -d, -f5 | sed 's/^ *//;s/ *$//')"
	expected_sha1="$(echo "${entry}" | cut -d, -f8 | sed 's/^ *//;s/ *$//')"

	[[ -z "${file_name}" ]] && continue

	image_path="${images_dir}/internal/${file_name}"
	if [[ ! -f "${image_path}" ]]; then
		missing+=("${file_name}")
		continue
	fi

	if [[ -n "${expected_sha1}" ]]; then
		actual_sha1="$(sha1sum "${image_path}" | cut -d' ' -f1)"
		if [[ "${actual_sha1}" != "${expected_sha1}" ]]; then
			hash_errors+=("${file_name}")
		fi
	fi
done < "${internal_index}"

[[ "${#missing[@]}" -eq 0 ]] || fail \
	"missing internal images: ${missing[*]}"
[[ "${#hash_errors[@]}" -eq 0 ]] || fail \
	"SHA-1 mismatch: ${hash_errors[*]}"

entry_count="$(wc -l < "${internal_index}")"
echo "QSPI-only package verification passed"
echo "  package:       ${package_dir}"
echo "  QSPI entries:  ${entry_count}"
echo "  external SSD:  disabled"
echo "  QSPI erase:    ${qspi_mode}"
