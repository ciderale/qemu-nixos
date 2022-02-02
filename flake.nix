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
    OVMF=nixpkgs.legacyPackages.x86_64-linux.OVMFFull.fd;
    NIXOS_ISO = pkgs.fetchurl {
      url = "https://channels.nixos.org/nixos-21.11/latest-nixos-minimal-x86_64-linux.iso";
      sha256 = "GMZK+F37p3/i9MxZCYlEu0gTx4qdtblGN2uSnRHjKwE=";
    };
  in rec {
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [qemu qemu-utils socat expect vmssh];
      inherit NIXOS_ISO OVMF SSH_PORT;
    };
  });
}
