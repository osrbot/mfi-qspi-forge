#!/usr/bin/env bash

set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
install_dir="${data_home}/mfi-qspi-forge"
apps_dir="${data_home}/applications"
bin_dir="${HOME}/.local/bin"
state_dir="${config_home}/mfi-qspi-forge"
icons_dir="${data_home}/icons/hicolor"
desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"

[[ -n "${desktop_dir}" ]] || desktop_dir="${HOME}/Desktop"

mkdir -p "${install_dir}" "${apps_dir}" "${bin_dir}" "${state_dir}" "${desktop_dir}"

install -m 0755 \
	"${source_dir}/make-qspi-only-mfi.sh" \
	"${source_dir}/verify-qspi-only-mfi.sh" \
	"${source_dir}/mfi-qspi-forge-gui.sh" \
	"${install_dir}/"

mkdir -p "${install_dir}/assets"
install -m 0644 \
	"${source_dir}/assets/qspi-skip-full-erase.patch" \
	"${install_dir}/assets/"

ln -sfn "${install_dir}/mfi-qspi-forge-gui.sh" \
	"${bin_dir}/mfi-qspi-forge"

for size in 48 64 128 256 512 1024; do
	icon_dir="${icons_dir}/${size}x${size}/apps"
	mkdir -p "${icon_dir}"
	install -m 0644 \
		"${source_dir}/assets/mfi-qspi-forge-${size}.png" \
		"${icon_dir}/mfi-qspi-forge.png"
done

desktop_file="${apps_dir}/mfi-qspi-forge.desktop"
cat > "${desktop_file}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MFI QSPI Forge
Comment=Create and flash a QSPI-only Seeed/NVIDIA MFI package
Exec=${bin_dir}/mfi-qspi-forge
Path=${HOME}
Icon=mfi-qspi-forge
Terminal=false
Categories=Utility;
StartupNotify=true
EOF
chmod 0755 "${desktop_file}"

desktop_copy="${desktop_dir}/MFI-QSPI-Forge.desktop"
cp "${desktop_file}" "${desktop_copy}"
chmod 0755 "${desktop_copy}"

if command -v gio >/dev/null; then
	gio set "${desktop_copy}" metadata::trusted true >/dev/null 2>&1 || true
fi

if command -v update-desktop-database >/dev/null; then
	update-desktop-database "${apps_dir}" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null; then
	gtk-update-icon-cache -f -t "${icons_dir}" >/dev/null 2>&1 || true
fi

"${install_dir}/mfi-qspi-forge-gui.sh" --check

echo "Installed to: ${install_dir}"
echo "Command:      ${bin_dir}/mfi-qspi-forge"
echo "GUI entry:    ${desktop_copy}"
