# Running NixOS in a QEMU VM

This repository experiments QEMU configurations for running NixOS as local VM. The NixOS installation is automated as much as possible. The setup assumes that nix/direnv is configured.

## Start

The initial boot process works with two separate script invocations.

The first script creates a fresh qcow disk image (erasing a previous one!)
and then booting a VM with the NixOS installation CD and the disk image.
```sh
./qemu-nixos.sh --fresh-vm
```

The second script invokes the actual installation of NixOS onto the mounted disk  image.
```sh
./qemu-nixos.sh --full-setup
```
It partitions the disk image and runs the nixos installer, followed by a reboot of the VM. The installation is done via SSH, after setting the "nixos" user's password via QEMU's monitoring console, to allow for ssh login the running VM.

After the initial installation, the VM can be started with
```sh
./qemu-nixos.sh --start
```
and login is provided for user "nixos" and password "nixos".

## Current state

* [X] The current configuration assumes the host is an intel based mac.
* [X] The boot process is done using UEFI boot
* [X] It uses apple's hypervisor framework (hvf) for accelleration
* [ ] Extend to run on M1 macs
* [ ] Enabling 9p based mount of host filesystem into the guest
			(https://github.com/NixOS/nixpkgs/pull/122420)
* [ ] Run docker in NixOS and provide it to the host system

