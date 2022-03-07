{
  description = "Configuration for NixOS in QEMU VM";

  inputs = {
    # use 9p patched qemu branch: https://github.com/NixOS/nixpkgs/pull/162243/commits
    nixpkgs.url = "github:nixos/nixpkgs/?rev=99a306df0220bbbe6b5a12c2d6434e5d51494275";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    colmena.inputs.flake-compat.follows = "flake-compat";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: let
    qemu-monitor = "10.0.2.11:60066";
    docker-port = 62375;
    ssh-port = 60022;
    modules = [
      ./configuration.nix
      ./docker-duck.nix
      {
        documentation.nixos.enable = false;
        docker-duck.qemu-monitor = qemu-monitor;
      }
    ];
  in {
    # TODO: combine colmena/nixosConfigurations/multi-arch
    colmena = import ./colmena.nix inputs {
      inherit modules ssh-port;
    };
    nixosConfigurations.docker-duck-aarch64 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      inherit modules;
    };
    nixosConfigurations.docker-duck-x86_64 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      inherit modules;
    };
  } // flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = nixpkgs.legacyPackages.${system};
    linuxSystem = builtins.replaceStrings ["darwin"] ["linux"] system;
    pkgsLinux = nixpkgs.legacyPackages.${linuxSystem};

    vmssh = import ./ssh.nix pkgs ''
      Host vm
        Hostname localhost
        Port ${toString ssh-port}
        User nixos
        UserKnownHostsFile=/dev/null
        StrictHostKeyChecking=no
    '';
    qemuNixos = pkgs.callPackage ./qemu-nixos.nix {
      inherit pkgsLinux ssh-port docker-port;
      monitor-socket = "/tmp/qemu-monitor-socket";
      monitor-in-vm = qemu-monitor;
      qemu-args = "";
    };

    colmena = inputs.colmena.packages."${system}".colmena;
    # docker has an issue in the branch of patched qemu
    docker = inputs.nixpkgs-unstable.legacyPackages.${system}.docker;
  in {
    devShell = pkgs.mkShell {
      buildInputs = [qemuNixos vmssh docker];
      # colmena currently needed, unless local deployments are made
      # buildInputs = [qemuNixos vmssh docker colmena];
      DOCKER_HOST = "tcp://localhost:${toString docker-port}";
    };
  });
}
