#!/usr/bin/env bash
args=(
  -m 16G -smp 4
  # accelleration
  -machine type=q35,accel=hvf -cpu Nehalem
  # networking
  -device e1000,netdev=net0
  -netdev user,id=net0,hostfwd=tcp::5555-:22
  # boot device
  -cdrom $NIXOS_ISO
)
qemu-system-x86_64 "${args[@]}"
