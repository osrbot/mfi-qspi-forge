#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "${script_path}")" && pwd)"
make_tool="${script_dir}/make-qspi-only-mfi.sh"
verify_tool="${script_dir}/verify-qspi-only-mfi.sh"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/mfi-qspi-forge"
last_source_file="${config_dir}/last-source"

if [[ -f "${last_source_file}" ]]; then
	default_source="$(<"${last_source_file}")"
else
	default_source="${HOME}"
fi

if [[ "${1:-}" = "--check" ]]; then
	for command in zenity gnome-terminal sha1sum tar; do
		command -v "${command}" >/dev/null || {
			echo "missing command: ${command}" >&2
			exit 1
		}
	done
	[[ -x "${make_tool}" ]] || {
		echo "missing tool: ${make_tool}" >&2
		exit 1
	}
	[[ -x "${verify_tool}" ]] || {
		echo "missing tool: ${verify_tool}" >&2
		exit 1
	}
	echo "GUI check: ok"
	exit 0
fi

show_error()
{
	zenity --error --width=560 --title="MFI QSPI Forge" --text="$1"
}

normalize_source()
{
	local selected="${1%/}"
	local candidate
	local -a candidates=()

	if [[ -f "${selected}/tools/kernel_flash/l4t_initrd_flash.sh" ]]; then
		echo "${selected}"
		return 0
	fi

	while IFS= read -r -d '' candidate; do
		if [[ -f "${candidate}/tools/kernel_flash/l4t_initrd_flash.sh" ]]; then
			candidates+=("${candidate}")
		fi
	done < <(find "${selected}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

	if [[ "${#candidates[@]}" -eq 1 ]]; then
		echo "${candidates[0]}"
		return 0
	fi

	return 1
}

run_with_progress()
{
	local title="$1"
	shift

	(
		"$@" 2>&1 | sed -u 's/^/# /'
		echo "# Finished"
	) | zenity --progress \
		--title="${title}" \
		--text="Working..." \
		--pulsate \
		--auto-close \
		--no-cancel \
		--width=560
}

source_dir="$(zenity --file-selection \
	--directory \
	--title="Select the new MFI package directory" \
	--filename="${default_source}/")" || exit 0

if ! source_dir="$(normalize_source "${source_dir}")"; then
	show_error "The selected directory does not contain a valid MFI package."
	exit 1
fi

erase_mode="$(zenity --list \
	--radiolist \
	--width=680 \
	--height=330 \
	--title="QSPI erase mode" \
	--text="Choose the QSPI erase mode." \
	--column="Select" \
	--column="Mode" \
	--column="Description" \
	TRUE "Fast" "Skip the 64 MiB full-chip erase. Use for blank/controlled-production devices." \
	FALSE "Full" "Erase the complete QSPI first. Use for recovery or reused devices.")" || exit 0

mkdir -p "${config_dir}"
printf '%s\n' "${source_dir}" > "${last_source_file}"

output_dir="${source_dir}-qspi-only-${erase_mode,,}"

if [[ -e "${output_dir}" ]]; then
	if ! zenity --question \
		--title="MFI QSPI Forge" \
		--text="A QSPI-only package already exists:\n\n${output_dir}\n\nVerify and reuse it?" \
		--ok-label="Verify and reuse" \
		--cancel-label="Choose another output"; then
		output_dir="$(zenity --entry \
			--title="QSPI-only output directory" \
			--text="Enter a new output directory:" \
			--entry-text="${output_dir}")" || exit 0

		if [[ -e "${output_dir}" ]]; then
			show_error "The output directory already exists:\n\n${output_dir}"
			exit 1
		fi
	fi
fi

if [[ ! -d "${output_dir}" ]]; then
	maker_args=("${make_tool}")
	if [[ "${erase_mode}" = "Fast" ]]; then
		maker_args+=("--fast")
	fi
	maker_args+=("${source_dir}" "${output_dir}")

	if ! run_with_progress "Creating QSPI-only MFI" "${maker_args[@]}"; then
		show_error "Failed to create the QSPI-only package.\n\nRun the maker tool from a terminal for details."
		exit 1
	fi
fi

verify_log="$(mktemp)"
if ! "${verify_tool}" "${output_dir}" >"${verify_log}" 2>&1; then
	show_error "QSPI-only verification failed:\n\n$(tail -n 25 "${verify_log}")"
	exit 1
fi

package_size="$(du -sh "${output_dir}" | cut -f1)"
zenity --info \
	--width=600 \
	--title="QSPI-only package ready" \
	--text="Verification passed.\n\nPackage:\n${output_dir}\n\nSize: ${package_size}\nQSPI mode: ${erase_mode}\nSSD/rootfs flashing: disabled" \
	|| exit 0

if ! zenity --question \
	--width=600 \
	--title="Flash QSPI-only package" \
	--text="Put the target into NVIDIA USB recovery mode, then continue.\n\nThis command flashes QSPI only. It does not write the SSD or rootfs." \
	--ok-label="Flash now" \
	--cancel-label="Not now"; then
	exit 0
fi

device_count="$(zenity --entry \
	--title="Massflash device count" \
	--text="Number of devices in recovery mode:" \
	--entry-text="1")" || exit 0

if [[ ! "${device_count}" =~ ^[1-9][0-9]*$ ]]; then
	show_error "Device count must be a positive integer."
	exit 1
fi

flash_command="cd $(printf '%q' "${output_dir}") && sudo ./tools/kernel_flash/l4t_initrd_flash.sh --flash-only --massflash $(printf '%q' "${device_count}") --network usb0 --showlogs; status=\$?; echo; if [ \"\$status\" -eq 0 ]; then echo 'QSPI flash completed successfully.'; else echo \"QSPI flash failed with exit code \$status.\"; fi; read -r -p 'Press Enter to close...'"

gnome-terminal \
	--title="MFI QSPI Forge" \
	-- bash -lc "${flash_command}"
