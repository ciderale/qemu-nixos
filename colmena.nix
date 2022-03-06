inputs: {
  meta = {
    nixpkgs = import inputs.nixpkgs {
      system = builtins.replaceStrings ["darwin"] ["linux"] builtins.currentSystem;
    };
  };
  qemu-nixos = {
    deployment = {
      targetHost = "localhost";
      targetPort = 60022;
      targetUser = "root";
      buildOnTarget = true;
    };
    imports = [
      ./configuration.nix
      ./docker-duck.nix
    ];
  };
}
