# MFI QSPI Forge

Create and flash a QSPI-only derivative of an existing Seeed/NVIDIA MFI
massflash package without modifying the original package.

The tool is intended for two-stage production:

1. Flash QSPI only.
2. Flash the SSD/rootfs separately when required.

## Features

- Removes the external SSD/rootfs image index from the derived package.
- Verifies all QSPI index entries and image SHA-1 hashes.
- Supports Fast and Full QSPI erase modes.
- Provides a Zenity-based GUI for package creation, verification, and flashing.
- Keeps the original MFI package read-only.

## Quick Start

Clone and install the user-local application:

```bash
git clone https://github.com/osrbot/mfi-qspi-forge.git
cd mfi-qspi-forge
./install-mfi-qspi-forge.sh
```

Launch the GUI from the desktop or application menu, or run:

```bash
mfi-qspi-forge
```

## GUI

Then launch `MFI QSPI Forge` from the desktop or application menu.

The GUI:

1. Selects an MFI package.
2. Selects Fast or Full mode.
3. Creates `<mfi-package>-qspi-only-fast` or
   `<mfi-package>-qspi-only-full`.
4. Verifies the derived package.
5. Opens a terminal for the massflash command.

## Command Line

Create a Fast-mode package:

```bash
./make-qspi-only-mfi.sh --fast \
  /path/to/mfi_package \
  /path/to/mfi_package-qspi-only-fast
```

Create a Full-mode package:

```bash
./make-qspi-only-mfi.sh \
  /path/to/mfi_package \
  /path/to/mfi_package-qspi-only-full
```

Verify either package:

```bash
./verify-qspi-only-mfi.sh /path/to/mfi_package-qspi-only-fast
```

Flash from the verified package:

```bash
cd /path/to/mfi_package-qspi-only-fast

sudo ./tools/kernel_flash/l4t_initrd_flash.sh \
  --flash-only \
  --massflash 1 \
  --network usb0 \
  --showlogs
```

## Fast vs Full Mode

`Fast` skips the vendor's 64 MiB full-chip QSPI erase. This is substantially
faster but is safe only for blank QSPI devices or controlled production lines
where stale data outside the written partitions is acceptable.

`Full` retains the complete QSPI erase. Use it for reused devices, recovery,
or whenever all reserved/unused regions must be cleared.

The actual partition write path uses `mtd_debug write`, which does not erase
NOR Flash automatically. Fast mode therefore relies on the target QSPI being
blank or otherwise known to be in a controlled state.

## Repository Contents

```text
make-qspi-only-mfi.sh          Create a QSPI-only package
verify-qspi-only-mfi.sh        Verify package structure and image hashes
mfi-qspi-forge-gui.sh          Zenity GUI
install-mfi-qspi-forge.sh      Install to ~/.local
assets/qspi-skip-full-erase.patch
assets/generate-mfi-qspi-icon.py
assets/mfi-qspi-forge-*.png
```

Vendor MFI packages, generated QSPI-only packages, flashing logs, and
machine-specific desktop files are intentionally ignored by Git.

## Development

Run the syntax checks:

```bash
make check
```

Regenerate the application icons:

```bash
make icons
```
