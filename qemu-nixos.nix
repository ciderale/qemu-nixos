{
  pkgs,
  pkgsLinux,
  monitor-socket ? null,
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
    "hostfwd=tcp::$SSH_PORT-:22"
    "hostfwd=tcp::$DOCKER_PORT-:2375"
    #"guestfwd=tcp:$QEMU_MONITOR_IN_VM-cmd: socat - unix-connect:$QEMU_MONITOR_SOCKET"
    "guestfwd=tcp:$QEMU_MONITOR_IN_VM-cmd: qemu-monitor"
  ];
  network = ''-device e1000,netdev=net0 -netdev "user,id=net0,${forwards}"'';

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
  # block device controller
  # https://www.qemu.org/2021/01/19/virtio-blk-scsi-configuration/
  # https://blogs.oracle.com/linux/post/how-to-emulate-block-devices-with-qemu
  -device ahci,id=achi0                         #SATA
  -device virtio-scsi-pci,id=scsi0,num_queues=4 #SCSI

  # boot cdrom
  -drive id=cd1,file=${nixosIso},format=raw,if=none,media=cdrom,readonly=on
  #-device ide-cd,drive=cd1,id=cd1,bootindex=1 #default
  #-device ide-cd,id=cd1,bus=achi0.0,drive=cd1,bootindex=1 #SATA
  -device scsi-hd,drive=cd1,bus=scsi0.0,channel=0,scsi-id=0,lun=1,bootindex=1 #virtio-scsi

  # block device configuration
  -drive id=hd1,file=${diskImg},format=qcow2,media=disk,if=none         # default
  #-device virtio-blk-pci,drive=hd1,id=virtblk0,num-queues=4,bootindex=0 # virtio-blk
  #-device ide-hd,id=hd1,bus=achi0.1,drive=hd1,bootindex=0               # SATA
  -device scsi-hd,drive=hd1,bus=scsi0.0,channel=0,scsi-id=0,lun=0,bootindex=0 #virtio-scsi

  # mounting of host file system into guest filesystem
  -virtfs local,path=/Users,security_model=mapped-xattr,mount_tag=host_users
  -virtfs local,path=/tmp,security_model=mapped-xattr,mount_tag=host_tmp
  '';

  qemu-nixos = pkgs.writeShellScriptBin "qemu-nixos" ''
    set -euo pipefail
    if [ "''${1:-}" == "--fresh" ]; then
      echo "Remove disk image and create new one"
      rm ${diskImg}
      ssh-keygen -R "[localhost]:$SSH_PORT"
      ${pkgs.qemu}/bin/qemu-img create -f qcow2 ${diskImg} ${diskSize}
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
    )
    ${qemu} "''${ARGS[@]}"
  '';


  qemuTools = pkgs.callPackage ./qemu-tools.nix {
    qemu-monitor-address = "unix-connect:${monitor-socket}";
  };
in
  pkgs.symlinkJoin {
    name = "qemu-nixos";
    paths = [qemuTools qemu-nixos];
  }
