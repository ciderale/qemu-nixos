nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nix-channel --update
nix-env -iA nixos.nix nixos.git

# mount flake repository into vm
OPTIONS="trans=virtio,version=9p2000.L,msize=104857600"
mkdir -p /Users && mount -t 9p -o $OPTIONS host_users /Users
# workaround missing tmp folder (https://github.com/NixOS/nixpkgs/issues/73404)
mkdir /mnt/mnt && mount --bind /mnt /mnt/mnt

FLAKE=/Users/ale/Projects/Dev/qemu-nixos#docker-duck
nixos-install --root /mnt --no-root-passwd --flake "$FLAKE"