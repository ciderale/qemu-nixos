DEVICE=/dev/vda
# Partitioning
parted $DEVICE -- mklabel gpt
parted $DEVICE -- mkpart primary 512MiB -8GiB
parted $DEVICE -- mkpart primary linux-swap -8GiB 100%
parted $DEVICE -- mkpart ESP fat32 1MiB 512MiB
parted $DEVICE -- set 3 esp on
# Formatting
mkfs.ext4 -L nixos ${DEVICE}1
mkswap -L swap ${DEVICE}2
mkfs.fat -F 32 -n boot ${DEVICE}3
# Pre-Installation
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon ${DEVICE}2
# Generate/Copy Configuration
# nixos-generate-config --root /mnt
