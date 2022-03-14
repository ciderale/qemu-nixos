{ config, lib, pkgs, modulesPath, ... }:
with lib;
let
  cfg = config.docker-duck;
  qemu-tools = pkgs.callPackage ./qemu-tools.nix {
    qemu-monitor-address = "tcp:${cfg.qemu-monitor}";
  };
  portmapperd = pkgs.writeShellScriptBin "portmapperd" (builtins.readFile ./portmapperd.sh);
  mounterd = pkgs.writeShellScriptBin "mounterd" (builtins.readFile ./mounterd.sh);
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

  # define temp file system of host and vm
  fileSystems."/.tmp_host" = {
    device = "host_tmp";
    fsType = "9p";
    options = [ "trans=virtio,version=9p2000.L,msize=104857600,nodevmap" ];
  };
  fileSystems."/.tmp_vm" = {
    device = "tmpfs";
    fsType = "tmpfs";
  };
  # merge host and local filesystem
  fileSystems."/tmptmp" = {
    device = "/.tmp_vm:/.tmp_host";
    fsType = "mergerfs";
    options = [ "allow_other,use_ino,category.create=epff" ];
  };
  fileSystems."/tmp" = {
    device = "/tmptmp";
    options = [ "bind" ];
  };

  virtualisation.docker = {
    enable = true;
    listenOptions = [
      "/run/docker.sock"
      "0.0.0.0:2375"
    ];
  };
  networking.firewall.allowedTCPPorts = [ 2375 ];
  networking.enableIPv6 = false;
  networking.tempAddresses = "disabled";

  environment.systemPackages = with pkgs; [
    docker qemu-tools mergerfs
  ];

/*
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
      */

 };
 }
