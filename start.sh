#!/usr/bin/env bash
DISK_IMG=./disk.img
SSH_PORT=2222
QEMU_MONITOR_SOCKET=qemu-monitor-socket
SETUP_PW=asdf
SSH_OPTS=(
  -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $SSH_PORT nixos@localhost
)
args=(
  -m 16G -smp 4
  # accelleration
  -machine type=q35,accel=hvf -cpu Nehalem
  -vga virtio
  -monitor unix:$QEMU_MONITOR_SOCKET,server,nowait
  # networking
  -device e1000,netdev=net0
  -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22

  ## Legacy BIOS Mode
  # boot device
  #-cdrom $NIXOS_ISO # booting with BIOS mode
  # main disk
  #-hda $DISK_IMG

  ## UEFI boot
  # https://unix.stackexchange.com/questions/530674/qemu-doesnt-respect-the-boot-order-when-booting-with-uefi-ovmf
  -drive if=pflash,format=raw,readonly=on,file=$OVMF/FV/OVMF.fd
  # boot cdrom
  -drive id=cd1,file=${NIXOS_ISO},format=raw,if=none,media=cdrom,readonly=on
  #-device ide-cd,drive=cd1,id=cd1,bootindex=1
  # https://wiki.gentoo.org/wiki/QEMU/Options#Hard_drive
  # using SATA/AHCI
  -device ahci,id=achi0
  -device ide-cd,id=cd1,bus=achi0.0,drive=cd1,bootindex=1
  -drive id=hd1,file=$DISK_IMG,format=qcow2,media=disk,if=none
  -device ide-hd,id=hd1,bus=achi0.1,drive=hd1,bootindex=0
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

function qemuMonitor() {
  socat - unix-connect:qemu-monitor-socket
}

function qemuType() {
  local TXT=$1
  (echo -n $TXT | grep -o . | sed -e 's/^/sendkey /'; echo "sendkey ret")
}

COMMAND=$1
case "$COMMAND" in
  --mkimg)
    mkDiskImg
    ;;
  --start)
    start
    ;;
  --set-ssh)
    (qemuType "passwd"; sleep 1) | qemuMonitor
    (qemuType $SETUP_PW; sleep 1) | qemuMonitor
    (qemuType $SETUP_PW; sleep 1) | qemuMonitor
    SSH_PORT=$SSH_PORT  SETUP_PASSWORD=$SETUP_PW ./copy-ssh-id.sh
    ;;
  --install)
    scp -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -P $SSH_PORT \
          uefi-install.sh configuration.nix nixos@localhost:
    ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p $SSH_PORT \
      nixos@localhost "sudo bash ./uefi-install.sh"
    ;;
  --ssh)
    ssh "${SSH_OPTS[@]}"
    ;;
esac
