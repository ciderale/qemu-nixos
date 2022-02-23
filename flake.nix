{
  description = "Configuration for NixOS in QEMU VM";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
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
    #x86_64
    #OVMF=nixpkgs.legacyPackages.x86_64-linux.OVMFFull.fd;
    #NIXOS_ISO = pkgs.fetchurl {
    #  url = "https://hydra.nixos.org/build/166431748/download/1/nixos-minimal-21.11.335749.4da27abaebe-x86_64-linux.iso";
    #  sha256 = "zdCAmGxy6MegeYa9aPMvLiQcpk0GTfOxyLPcld0wh9I=";
    #};
    #aarch64
    OVMF=nixpkgs.legacyPackages.aarch64-linux.OVMF.fd;
    NIXOS_ISO = pkgs.fetchurl {
      #url = "https://hydra.nixos.org/build/166431748/download/1/nixos-minimal-21.11.335749.4da27abaebe-x86_64-linux.iso";
      url = "https://hydra.nixos.org/build/167910054/download/1/nixos-minimal-21.11.336125.cc81cf48115-aarch64-linux.iso";
      sha256 = "KA1vlJcq9+PkI+cXa+gir3upRfpUYwMJdO11HymYiiU=";
    };
  in rec {
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [qemu qemu-utils socat expect vmssh];
      inherit NIXOS_ISO OVMF SSH_PORT;
    };
  });
}
