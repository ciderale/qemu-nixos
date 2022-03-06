{
  description = "Configuration for NixOS in QEMU VM";

  inputs = {
    # use 9p patched qemu branch: https://github.com/NixOS/nixpkgs/pull/162243/commits
    nixpkgs.url = "github:nixos/nixpkgs/?rev=99a306df0220bbbe6b5a12c2d6434e5d51494275";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    colmena.inputs.flake-compat.follows = "flake-compat";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: {
    colmena = import ./colmena.nix inputs;
    nixosConfigurations.docker-duck = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux"; # how to stay multi-architecture?
      modules = [
        ./configuration.nix
        ./docker-duck.nix
        { documentation.nixos.enable = false; }
      ];
    };
  } // flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = nixpkgs.legacyPackages.${system};
    linuxSystem = builtins.replaceStrings ["darwin"] ["linux"] system;
    pkgsLinux = nixpkgs.legacyPackages.${linuxSystem};

    SSH_PORT=self.colmena.qemu-nixos.deployment.targetPort;
    DOCKER_PORT=62375;
    QEMU_MONITOR_IN_VM = "10.0.2.11:60066";

    vmssh = import ./ssh.nix pkgs ''
      Host vm
        Hostname localhost
        Port ${toString SSH_PORT}
        User nixos
        UserKnownHostsFile=/dev/null
        StrictHostKeyChecking=no
    '';
    colmenaX = inputs.colmena.packages."${system}".colmena;

    qemuNixos = pkgs.callPackage ./qemu-nixos.nix {
      inherit pkgsLinux;
      monitor-socket = "/tmp/qemu-monitor-socket";
      qemu-args = "";
    };

  in rec {
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [qemuNixos vmssh colmenaX docker];
      inherit SSH_PORT DOCKER_PORT QEMU_MONITOR_IN_VM system;
      DOCKER_HOST = "tcp://localhost:${toString DOCKER_PORT}";
    };
  });
}
