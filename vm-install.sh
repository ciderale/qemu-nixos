nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nix-channel --update
nix-env -iA nixos.nix nixos.git
mkdir -p /Users && mount -t 9p host_users /Users
nixos-install --no-root-passwd --flake /Users/ale/Projects/Dev/qemu-nixos#docker-duck
