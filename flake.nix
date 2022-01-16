{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    #nixpkgs.url = "github:r2r-dev/nixpkgs/qemu-darwin-fixes";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: {
  } // flake-utils.lib.eachDefaultSystem (system:
  let pkgs = nixpkgs.legacyPackages.${system};
  in rec {
    iso = pkgs.fetchurl {
      url = "https://channels.nixos.org/nixos-21.11/latest-nixos-minimal-x86_64-linux.iso";
      sha256 = "GMZK+F37p3/i9MxZCYlEu0gTx4qdtblGN2uSnRHjKwE=";
    };
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [qemu qemu-utils socat expect];
      NIXOS_ISO=iso;
    };
  });
}
