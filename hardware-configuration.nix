{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  # generated with 'nixos-generate-config --root /mnt'
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "virtio_pci" "virtio_scsi" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # adapted manually to "by-label"
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ { 
    device = "/dev/disk/by-label/swap"; 
  } ];

}
