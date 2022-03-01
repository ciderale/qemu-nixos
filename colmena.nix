inputs: {
  meta = {
    nixpkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
    };
  };
  qemu-nixos = {
    deployment = {
      targetHost = "localhost";
      targetPort = 2222;
      targetUser = "root";
      buildOnTarget = true;
    };
    imports = [
      ./configuration.nix
      ./docker-duck.nix
    ];
  };
}
