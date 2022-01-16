#!/usr/bin/env bash

qemu-system-x86_64 \
  -m 16G -smp 4 \
  -cdrom $NIXOS_ISO \
