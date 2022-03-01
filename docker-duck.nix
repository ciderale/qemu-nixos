{ config, lib, pkgs, modulesPath, ... }:

{

  fileSystems."/Users" = {
    device = "host_users";
    fsType = "9p";
    options = [ "trans=virtio,version=9p2000.L,msize=104857600" ];
  };

# this causes problems with sockets (e.g. pty from docker run -ti)
#  fileSystems."/tmp" = {
#    device = "host_tmp";
#    fsType = "9p";
#    options = [ "trans=virtio,version=9p2000.L,msize=104857600" ];
#  };

  virtualisation.docker = {
    enable = true;
    listenOptions = [
      "/run/docker.sock"
      "0.0.0.0:2375"
    ];
  };
  networking.firewall.allowedTCPPorts = [ 2375 ];

  environment.systemPackages = with pkgs; [
    docker
  ];

}
