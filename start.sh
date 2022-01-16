#!/usr/bin/env bash

qemu-system-x86_64 \
  -m 16G -smp 4 \
  -machine type=q35,accel=hvf -cpu Nehalem \
  -cdrom $NIXOS_ISO \



