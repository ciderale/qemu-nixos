# Running NixOS in a QEMU VM

This repository experiments QEMU configurations for running NixOS as local VM. The NixOS installation is automated as much as possible. The setup assumes that nix/direnv is configured.


## Normal start

* Start the vm with `./qemu-nixos.sh --start`
* Enter the vm with `ssh vm`
* Docker is available on port `tcp://` which is configured by direnv

## Installation

The initial boot process works with two separate script invocations.

The first script creates a fresh qcow disk image (erasing a previous one!)
and installs a base configuration using the nixos installer. The script
reboots the vm after installation and leaves it in a ready state.

```sh
./qemu-nixos.sh --fresh
```

The second script deploys the actual configuration enabling docker with
all necessary services to expose ports to the host system and to mount
files from the /tmp directory. Applying this configuration is as simple as:

```sh
colmena apply
```

### Known installation caveats

* adapt network interface number ens2 (intel) or ens3 (m1) in configuration.nix
* installation requires configured ssh public keys in configuration.nix
* 9p support requires patched qemu which currently is built locally

## Current state

* [X] Setup for Intel & M1 based macs
* [X] Use apple's hypervisor framework (hvf) for accelleration
* [X] UEFI based boot process
* [X] Sound support
* [X] Colmena remote deployment
* [X] Enabling 9p based mount of host filesystem into the guest
	    https://github.com/NixOS/nixpkgs/pull/122420
* [X] Run docker in NixOS and provide it to the host system
* [X] Docker port forwarding to host sytem
* [X] Volume mount of /tmp (or files in there)
* [ ] tmp mounter: remove stale directory if host tmp is a file
* [ ] adapt configuration to have same ens2/3 interface on intel&m1
* [ ] nixify the qemu-nixos.sh configuration script
* [ ] keep nixpkgs of nixos-install and colmena in sync

## Details

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

