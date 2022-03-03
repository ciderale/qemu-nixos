{ config, pkgs, ... }:

{

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.windowManager.awesome.enable = true;
  #services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.resolutions = [
    { x=1280; y=1024; }
  ];

  # Configure keymap in X11
  services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    firefox # alsa-utils
  ];
}

