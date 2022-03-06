inputs: config: {
  meta = {
    nixpkgs = import inputs.nixpkgs {
      system = builtins.replaceStrings ["darwin"] ["linux"] builtins.currentSystem;
    };
  };
  qemu-nixos = {
    deployment = {
      targetHost = "localhost";
      targetPort = config.ssh-port;
      targetUser = "root";
      buildOnTarget = true;
    };
    imports = config.modules;
  };
}
