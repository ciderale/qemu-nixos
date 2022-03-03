#!/usr/bin/env bash
set -x
DISK_IMG=./disk.img
QEMU_MONITOR_SOCKET=qemu-monitor-socket
args=(
  $QEMU_PARAMS
  -m 16G -smp 4
  -serial stdio
  -display default,show-cursor=on -device usb-tablet # show cursor
  -monitor unix:$QEMU_MONITOR_SOCKET,server,nowait
  -monitor tcp:localhost:4444,server,nowait
  # networking
  -device e1000,netdev=net0
  -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22,hostfwd=tcp::2375-:2375,host=10.0.2.2,guestfwd=tcp:10.0.2.11:4444-cmd: nc localhost 4444"

  # audio
  -audiodev coreaudio,id=audio -device intel-hda -device hda-output,audiodev=audio

  # block device controller
  # https://www.qemu.org/2021/01/19/virtio-blk-scsi-configuration/
  # https://blogs.oracle.com/linux/post/how-to-emulate-block-devices-with-qemu
  -device ahci,id=achi0                         #SATA
  -device virtio-scsi-pci,id=scsi0,num_queues=4 #SCSI

  # boot cdrom
  -drive id=cd1,file=${NIXOS_ISO},format=raw,if=none,media=cdrom,readonly=on
  #-device ide-cd,drive=cd1,id=cd1,bootindex=1 #default
  #-device ide-cd,id=cd1,bus=achi0.0,drive=cd1,bootindex=1 #SATA
  -device scsi-hd,drive=cd1,bus=scsi0.0,channel=0,scsi-id=0,lun=1,bootindex=1 #virtio-scsi

  # block device configuration
  -drive id=hd1,file=$DISK_IMG,format=qcow2,media=disk,if=none         # default
  #-device virtio-blk-pci,drive=hd1,id=virtblk0,num-queues=4,bootindex=0 # virtio-blk
  #-device ide-hd,id=hd1,bus=achi0.1,drive=hd1,bootindex=0               # SATA
  -device scsi-hd,drive=hd1,bus=scsi0.0,channel=0,scsi-id=0,lun=0,bootindex=0 #virtio-scsi

  # mounting of host file system into guest filesystem
  -virtfs local,path=/Users,security_model=mapped-xattr,mount_tag=host_users
  -virtfs local,path=/tmp,security_model=mapped-xattr,mount_tag=host_tmp
)

function start() {
  $QEMU_BIN "${args[@]}"
}

function mkDiskImg() {
  [ -e $DISK_IMG ] && \
    echo "Disk image exists. Manually delete $DISK_IMG" && \
    exit 1
  qemu-img create -f qcow2 $DISK_IMG 100G
}

function qemuMonitor() {
  socat - unix-connect:$QEMU_MONITOR_SOCKET
}

function qemuMonitor2() {
  (cat ; sleep 1) | qemuMonitor
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
    SETUP_PW=asdf
    qemuType "passwd" | qemuMonitor2
    qemuType $SETUP_PW | qemuMonitor2
    qemuType $SETUP_PW | qemuMonitor2
    PASSWORD=$SETUP_PW ssh-copy-id-password vm
    ;;
  --install)
    scp uefi-install.sh {hardware-,}configuration.nix nixos@vm:
    BEFORE=$(date)
    ssh nixos@vm "sudo bash ./uefi-install.sh"
    DONE=$(date)
    echo "BEFORE: $BEFORE"
    echo "DONE:   $DONE"
    ;;

  --fresh-vm)
    rm disk.img
    ssh-keygen -R '[localhost]:2222'
    $0 --mkimg
    $0 --start
    ;;

  --full-setup)
    waitForSsh vm
    $0 --set-ssh
    $0 --install
    ;;

  --fresh)
    $0 --fresh-vm &
    sleep 10
    $0 --full-setup
    sleep 15 # wait that vm is fully shut down
    echo "#############################################"
    echo "#####  Installation completed  ##############"
    echo "#############################################"
    $0 --start
    ;;
esac
