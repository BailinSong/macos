#!/usr/bin/env bash
set -Eeuo pipefail

: "${APP:="macOS"}"
: "${VGA:="vmware"}"
: "${DISK_TYPE:="blk"}"
: "${SUPPORT:="Bailin"}"
: "${SUPPORT:="Bailin"}"
: "${VNCPASSWORD:="reindeer"}"


cd /run

. reset.sh      # Initialize system
. install.sh    # Get the OSX images
. disk.sh       # Initialize disks
. display.sh    # Initialize graphics
. network.sh    # Initialize network
. boot.sh       # Configure boot
. proc.sh       # Initialize processor
. config.sh     # Configure arguments

trap - ERR

version=$(qemu-system-x86_64 --version | head -n 1 | cut -d '(' -f 1 | awk '{ print $NF }')
info "Booting ${APP}${BOOT_DESC} using QEMU v$version..."

echo "qemu-system-x86_64 ${ARGS:+ $ARGS}"

exec qemu-system-x86_64 ${ARGS:+ $ARGS}
