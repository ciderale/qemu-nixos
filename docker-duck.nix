{ config, lib, pkgs, modulesPath, ... }:
with lib;
let
  cfg = config.docker-duck;
  mounter = pkgs.writeShellScriptBin "mounter" ''
      # create bind mounts
      for i in $(comm -1 -3 <(ls -1 /tmp) <(ls /.tmp/)); do
        test -d /.tmp/$i && mkdir /tmp/$i || touch /tmp/$i;
        ${pkgs.mount}/bin/mount --bind /.tmp/$i /tmp/$i;
        echo "bind mount $i";
      done
      # remove stale bind mounts
      for i in /tmp/*; do
        test ! -e $i && echo "unbind $i" && ${pkgs.umount}/bin/umount $i && rm -d $i
      done
  '';
  mounterd = pkgs.writeShellScriptBin "mounterd" ''
       ${pkgs.docker}/bin/docker events | while read; do ${mounter}/bin/mounter; done
  '';
  qemu-tools = pkgs.callPackage ./qemu-tools.nix {
    qemu-monitor-address = "tcp:${cfg.qemu-monitor}";
  };
  portmapperd = pkgs.writeShellScriptBin "portmapperd" (builtins.readFile ./portmapperd.sh);
in
  {
    options.docker-duck.qemu-monitor = mkOption {
      type = types.str;
      description = "the ip and port to reach the qemu monitor connection";
    };
    config =

{

  fileSystems."/Users" = {
    device = "host_users";
    fsType = "9p";
    options = [ "trans=virtio,version=9p2000.L,msize=104857600" ];
  };

  fileSystems."/.tmp" = { # mounterd will selectively mount /.tmp/* => /tmp/*
    device = "host_tmp";
    fsType = "9p";
    options = [ "trans=virtio,version=9p2000.L,msize=104857600,nodevmap" ];
    #neededForBoot = true;
  };

  virtualisation.docker = {
    enable = true;
    listenOptions = [
      "/run/docker.sock"
      "0.0.0.0:2375"
    ];
  };
  networking.firewall.allowedTCPPorts = [ 2375 ];

  environment.systemPackages = with pkgs; [
    docker qemu-tools
  ];

  systemd.services.dockerTmpMounter = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Bind (un-)mount files and directories from host tmp to guest tmp";
      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStart = ''${mounterd}/bin/mounterd'';
      };
   };

   systemd.services.dockerPortmapper = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "forward exposed docker ports from guest to host";
      path = with pkgs; [qemu-tools docker gnugrep gawk];
      serviceConfig = {
        Type = "simple";
        ExecStart = ''${portmapperd}/bin/portmapperd'';
      };
   };

 };
 }
