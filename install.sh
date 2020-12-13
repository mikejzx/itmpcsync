#!/bin/sh

# Installs the application.
# Modify INSTALL_PREFIX to whereever you want.

INSTALL_PREFIX="$HOME/.local/bin"

if [[ ! -f "$INSTALL_PREFIX" ]]; then
	mkdir -p "$INSTALL_PREFIX" || exit -1
fi

cp bin/itxmlconvert "$INSTALL_PREFIX"
cp itmpcsync "$INSTALL_PREFIX"
