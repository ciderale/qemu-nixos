{ config, lib, pkgs, modulesPath, ... }:

{

  fileSystems."/Users" = {
    device = "host_users";
    fsType = "9p";
    options = [ "trans=virtio,version=9p2000.L,msize=104857600" ];
  };

  fileSystems."/tmp" = {
    device = "host_tmp";
    fsType = "9p";
    options = [ "trans=virtio,version=9p2000.L,msize=104857600" ];
  };

}
