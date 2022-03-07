PATH_TO_FLAKE=$1
nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nix-channel --update
nix-env -iA nixos.nix nixos.git

# mount flake repository into vm
OPTIONS="trans=virtio,version=9p2000.L,msize=104857600"
mkdir -p /Users && mount -t 9p -o $OPTIONS host_users /Users
# workaround missing tmp folder (https://github.com/NixOS/nixpkgs/issues/73404)
mkdir -p /mnt/mnt && mount --bind /mnt /mnt/mnt

FLAKE=${PATH_TO_FLAKE}#docker-duck-$(uname -m)
echo "installing $FLAKE"
nixos-install --root /mnt --no-root-passwd --flake "$FLAKE"
