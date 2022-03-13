{
  pkgs,
  pkgsLinux,
  monitor-socket ? null,
  monitor-in-vm,
  ssh-port,
  docker-port,
  nographics ? false,
  diskImg ? "/tmp/disk.img",
  diskSize ? "100G",
  qemu-args
}:
with pkgs.lib;
let
  arch = if (pkgs.stdenv.isx86_64) then "x86_64" else "aarch64";
  qemu = "${pkgs.qemu}/bin/qemu-system-${arch}";
  machineDef = if pkgs.stdenv.isx86_64 then ''
    -machine type=q35,accel=hvf -cpu Nehalem
    -vga virtio -usb
    -drive if=pflash,format=raw,readonly=on,file=${pkgsLinux.OVMFFull.fd}/FV/OVMF.fd
  '' else ''
    -cpu cortex-a72 -M virt,highmem=off -accel hvf
    -device virtio-gpu-pci
    -device qemu-xhci
    -device usb-kbd
    -bios ${pkgsLinux.OVMF.fd}/FV/QEMU_EFI.fd
  '';

  monitor = optionalString (monitor-socket != null) "-monitor unix:${monitor-socket},server,nowait";

  forwards = concatStringsSep "," [
    "hostfwd=tcp::${toString ssh-port}-:22"
    "hostfwd=tcp::${toString docker-port}-:2375"
    # could be done with gateway address
    "guestfwd=tcp:${monitor-in-vm}-cmd: qemu-monitor"
  ];

  network = ''-device virtio-net-pci,netdev=net0 -netdev "user,id=net0,${forwards}"'';

  graphics = if nographics then "-nographic" else ''
    -display default,show-cursor=on -device usb-tablet # show cursor
  '';
  audio = "-audiodev coreaudio,id=audio -device intel-hda -device hda-output,audiodev=audio";

  fetchHydra = { build, name, sha256 }: pkgs.fetchurl {
    url = "https://hydra.nixos.org/build/${build}/download/1/${name}.iso";
    inherit sha256;
  };
  nixosIso = if (pkgs.stdenv.isx86_64) then fetchHydra {
    build = "166431748";
    name = "nixos-minimal-21.11.335749.4da27abaebe-x86_64-linux";
    sha256 = "zdCAmGxy6MegeYa9aPMvLiQcpk0GTfOxyLPcld0wh9I=";
  } else fetchHydra {
    build = "167910054";
    name = "nixos-minimal-21.11.336125.cc81cf48115-aarch64-linux";
    sha256 = "KA1vlJcq9+PkI+cXa+gir3upRfpUYwMJdO11HymYiiU=";
  };

  storage = ''
    # drive definitions
    -drive id=cd1,file=${nixosIso},format=raw,if=none,media=cdrom,readonly=on
    -drive id=hd1,file=${diskImg},format=qcow2,media=disk,if=none

    # device definitions
    -device virtio-blk-pci,drive=hd1,bootindex=0
    -device virtio-blk-pci,drive=cd1,bootindex=1
  '';
  # some experiments:
    # check read speed with: hdparm -tT /dev/vda
    # block device controller
    # https://www.qemu.org/2021/01/19/virtio-blk-scsi-configuration/
    # https://blogs.oracle.com/linux/post/how-to-emulate-block-devices-with-qemu
    #-device ahci,id=achi0                         #SATA
    #-device virtio-scsi-pci,id=scsi0,num_queues=4 #SCSI

    # boot cdrom
    #-device ide-cd,drive=cd1,id=cd1,bootindex=1 #default
    #-device ide-cd,id=cd1,bus=achi0.0,drive=cd1,bootindex=1 #SATA
    #-device scsi-hd,drive=cd1,bus=scsi0.0,channel=0,scsi-id=0,lun=1,bootindex=1 #virtio-scsi
    #-device virtio-blk-pci,drive=hd1,id=virtblk0,num-queues=1,bootindex=0 # virtio-blk
    #-device ide-hd,id=hd1,bus=achi0.1,drive=hd1,bootindex=0               # SATA
    #-device scsi-hd,drive=hd1,bus=scsi0.0,channel=0,scsi-id=0,lun=0,bootindex=0 #virtio-scsi

  mounts = ''
    # mounting of host file system into guest filesystem
    -virtfs local,path=/Users,security_model=mapped-xattr,mount_tag=host_users
    -virtfs local,path=/tmp,security_model=mapped-xattr,mount_tag=host_tmp
  '';

  qemu-nixos-install = pkgs.writeShellScriptBin "qemu-nixos-install" ''
    echo "## Create fresh disk image"
    rm -i ${diskImg}
    ${pkgs.qemu}/bin/qemu-img create -f qcow2 ${diskImg} ${diskSize}

    echo "## Start VM in background and wait for SSH access"
    qemu-nixos &
    ssh-keygen -R "[localhost]:${toString ssh-port}"
    waitForSsh vm

    echo "## Setup login password"
    SETUP_PW=asdf
    qemu-type "passwd"; sleep 1
    qemu-type $SETUP_PW; sleep 1
    qemu-type $SETUP_PW; sleep 1
    PASSWORD=$SETUP_PW ssh-copy-id-password vm

    echo "## Partition and Install nixos"
    scp vm-partitioning.sh vm-install.sh nixos@vm:
    ssh nixos@vm "sudo bash ./vm-partitioning.sh"
    PATH_TO_FLAKE=$(pwd)
    echo $PATH_TO_FLAKE
    ssh nixos@vm "sudo bash ./vm-install.sh $PATH_TO_FLAKE"

    echo "configure authorized key in new installation"
    SSH_DIR=/home/nixos/.ssh
    AK=$SSH_DIR/authorized_keys
    ssh nixos@vm "mkdir -p /mnt/$SSH_DIR; cat $AK >> /mnt/$AK; chmod 600 /mnt/$AK; sync"

    echo "## Installation completed; shutdown VM"
    qemu-pipe <<< "quit"
  '';

  qemu-nixos = pkgs.writeShellScriptBin "qemu-nixos" ''
    set -euo pipefail
    if [ "''${1:-}" == "--fresh" ]; then
      qemu-nixos-install
    elif [ ! -e ${diskImg} ]; then
      echo "there is no disk image at ${diskImg}"
      echo "disk image will be created"
      read -p "press any key to continue or ctrl-c to abort"
      qemu-nixos-install
    fi
    ARGS=(
      ${machineDef}
      ${monitor}
      ${network}
      --serial stdio
      -m 16G -smp 4
      ${graphics}
      ${audio}
      ${qemu-args}
      ${storage}
      ${mounts}
    )
    ${qemu} "''${ARGS[@]}"
  '';


  qemuTools = pkgs.callPackage ./qemu-tools.nix {
    qemu-monitor-address = "unix-connect:${monitor-socket}";
  };
in
  pkgs.symlinkJoin {
    name = "qemu-nixos";
    paths = [qemuTools qemu-nixos qemu-nixos-install];
  }
