{
  description = "Configuration for NixOS in QEMU VM";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    colmena.inputs.flake-compat.follows = "flake-compat";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: {
  } // flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = nixpkgs.legacyPackages.${system};

    SSH_PORT="2222";
    vmssh = import ./ssh.nix pkgs ''
      Host vm
        Hostname localhost
        Port ${SSH_PORT}
        User nixos
        UserKnownHostsFile=/dev/null
        StrictHostKeyChecking=no
    '';
    qemu_args = {
      x86_64-darwin = rec {
        OVMF = nixpkgs.legacyPackages.x86_64-linux.OVMFFull.fd;
        NIXOS_ISO = pkgs.fetchurl {
          url = "https://hydra.nixos.org/build/166431748/download/1/nixos-minimal-21.11.335749.4da27abaebe-x86_64-linux.iso";
          sha256 = "zdCAmGxy6MegeYa9aPMvLiQcpk0GTfOxyLPcld0wh9I=";
        };
        QEMU_BIN="qemu-system-x86_64";
        QEMU_PARAMS=''
  -machine type=q35,accel=hvf -cpu Nehalem
  -vga virtio
  -usb 
  -drive if=pflash,format=raw,readonly=on,file=${OVMF}/FV/OVMF.fd
        '';
  ## UEFI boot
  # https://unix.stackexchange.com/questions/530674/qemu-doesnt-respect-the-boot-order-when-booting-with-uefi-ovmf
      };
      aarch64-darwin = rec {
        OVMF=nixpkgs.legacyPackages.aarch64-linux.OVMF.fd;
        NIXOS_ISO = pkgs.fetchurl {
          url = "https://hydra.nixos.org/build/167910054/download/1/nixos-minimal-21.11.336125.cc81cf48115-aarch64-linux.iso";
          sha256 = "KA1vlJcq9+PkI+cXa+gir3upRfpUYwMJdO11HymYiiU=";
        };
        QEMU_BIN="qemu-system-aarch64";
        QEMU_PARAMS=''
  -cpu cortex-a72 -M virt,highmem=off -accel hvf
  -device virtio-gpu-pci
  -device qemu-xhci
  -device usb-kbd
  -bios ${OVMF}/FV/QEMU_EFI.fd
          '';
      };
    };
    colmenaX = inputs.colmena.packages."${system}".colmena;
  in rec {
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [qemu qemu-utils socat expect vmssh colmenaX];
      inherit SSH_PORT system;
      inherit (qemu_args."${system}") NIXOS_ISO OVMF QEMU_BIN QEMU_PARAMS;
    }; # // (qemu_args."${system}");
  });
}
