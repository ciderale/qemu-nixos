{ config, lib, pkgs, modulesPath, ... }:
let
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
  qemu-monitor = pkgs.writeShellScriptBin "qemu-monitor" ''
    ${pkgs.socat}/bin/socat - tcp:10.0.2.11:4444
  '';
in

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
    docker qemu-monitor
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

}
