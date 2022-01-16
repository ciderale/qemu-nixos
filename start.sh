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
  # networking
  -device e1000,netdev=net0
  -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22
  # boot device
  -cdrom $NIXOS_ISO
  # main disk
  -hda $DISK_IMG
  -monitor unix:$QEMU_MONITOR_SOCKET,server,nowait
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
  --ssh)
    ssh "${SSH_OPTS[@]}"
    ;;
esac
