#!/usr/bin/env bash
DISK_IMG=./disk.img
args=(
  -m 16G -smp 4
  # accelleration
  -machine type=q35,accel=hvf -cpu Nehalem
  # networking
  -device e1000,netdev=net0
  -netdev user,id=net0,hostfwd=tcp::5555-:22
  # boot device
  -cdrom $NIXOS_ISO
  # main disk
  -hda $DISK_IMG
)

function start() {
  qemu-system-x86_64 "${args[@]}"
}

function mkDiskImg() {
  [ -e $DISK_IMG ] && \
    echo "Disk image exists. Manually delete $DISK_IMG" && \
    exit 1
  qemu-img create -f qcow2 $DISK_IMG 100G
}

COMMAND=$1
case "$COMMAND" in
  --mkimg)
    mkDiskImg
    ;;
  --start)
    start
    ;;
esac
