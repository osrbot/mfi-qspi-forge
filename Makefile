SHELL := /bin/bash

.PHONY: check install icons

check:
	bash -n make-qspi-only-mfi.sh
	bash -n verify-qspi-only-mfi.sh
	bash -n mfi-qspi-forge-gui.sh
	bash -n install-mfi-qspi-forge.sh
	python3 -m py_compile assets/generate-mfi-qspi-icon.py

install:
	./install-mfi-qspi-forge.sh

icons:
	python3 assets/generate-mfi-qspi-icon.py
