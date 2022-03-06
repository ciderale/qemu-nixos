# Running NixOS & Docker in a QEMU VM

This repository provides a NixOS/QEMU configurations to provide a docker environment with smooth integration with a MacOS host system. The system works on intel and m1 macs. It assumes nix & direnv is configured

## Start

* Prerequisite: Nix (with flake support) is installed
* Prerequisite: Configure (nix-)direnv or use `nix develop` shell
* Start the vm with `qemu-nixos`
* Enter the vm with `ssh vm`
* `DOCKER_HOST=tcp://localhost:62375` is configured by direnv

### Known installation caveats

* 9p support requires patched qemu which currently is built locally
  (it will be in 7.0 and the 6.2 back-port will soon by in nixpkgs and it's cache)

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
* [X] nixify the qemu-nixos.sh configuration script
* [X] nixos-installation using --flakes
* [X] keep nixpkgs of nixos-install and colmena in sync
* [ ] replace colemena with deploy-rs do avoid duplicating nixos configuration
* [ ] tmp mounter: remove stale directory if host tmp is a file
* [ ] adapt configuration to have same ens2/3 interface on intel&m1

# Architecture / Challenges and Solutions

Providing docker functionality on MacOS with smooth integration requires
various details to be solved. The following list gives an overview:

* Docker is linux: Hence, a running linux system is needed
* Linux on MacOS: Some virtualisation solution is needed
* Performance: virtualisation requires acceleration
* Access docker from MacOS: daemon socket must be exposed to MacOS
* Access exposed docker ports: Dynamically forward linux to MacOS ports
* Bind-mount host filesystem: mount MacOS filesystem into linux VM

Additionally, the system should be robust and simple to run. Hence,
installation and updates must be automated as much as possible.

The corner stones of this solutions are QEMU and NixOS:

* QEMU is a robust, widely-used, open-source hypervisor
* QEMU performs on Intel and M1 by leveraging apple's hypervisor framework
* NixOS's declarative approach is ideal to automate many aspects
* NixOS's reproducibility is key for simple installations

The following sections detail challenges encountered.

## Docker Port-Forwarding

Port forwarding from the QEMU VM to MacOS is crucial. It is required to start
and stop containers, but also to interact with the dockerised applications.
This section describes the three types of port forwards used by the system.

Firstly, the docker daemon connection must be forwarded to interact with docker
from MacOS (e.g. start/stop/inspection of containers). Forwarding the docker
daemon is straightforward as the docker daemon port is statically known. Hence
the port forward can be activated on start of QEMU.

Secondly, the ports exposed by docker containers need to be forwarded to use
the dockerised applications from MacOS. This is more challenging since ports
appear and disappear as containers are started and stopped. Forwarding
pre-defined port ranges seems sub-optimal and cause conflicts on the host
system. Hence, forwarding those ports must be dynamic. Fortunately,
manipulation of host-forwards is possible at runtime using QEMU's monitor
interface. To this end, a service listens to `docker events` and synchronises
the ports exposed by docker with the port forwarding table of QEMU.

Thirdly, the QEMU monitor connection on MacOS is made accessible within the VM.
This allows for running the port forward sync service in linux and avoid
additional complexity on the MacOS side. This is a "guest-forward" that flows
in the opposite direction to the above "host-forwards". Fortunately, this 
guest-forward is static and can be established on start of QEMU.

## Docker Volume Mounts

Volume mounts are also crucial. They are often used to provide configurations
to dockerised applications or the keep persistent state out of the containers.
The challenge is to mount files and folders from the MacOS filesystem. Without
special handling, the docker daemon mounts files from the linux VM. That would not
include files and folder created in MacOS.

Fortunately, recent development added the "9p" protocol to mount the MacOS
filesystem into the guest VM. This works well for non-system folder like
`/Users`. The current solutions mounts the entire `/Users` folder, but more
granular scheme could be envisioned to improve isolation between the guest and
the host. In general a static list of accessible folders seems sufficient
though.

### Volume Bind Mounts in /tmp

Unfortunately, mounting `/tmp` is not that straightforward.
The problem is that there are two competing use cases:

* On the one hand, mounting temporary configuration or data folders into
docker containers is a quite common pattern for local development setups.
That requires mounting the hosts `/tmp` into the guest.

* On the other hand, the guest OS uses `/tmp` for various purposes, including
the creation of e.g. unix domain sockets. Unfortunately such special files
cannot be created in a "9p" (or other host mounted) filesystem. Hence, `/tmp`
should not be mounted from the host into the guest.

A solution to this dilemma is to mount MacOS's `/tmp` to an alternate
location like `/.tmp`. Then every file or folder is bind-mounted _individually_
from the alternate temporary folder to the actual temporary folder. As a result,
we have:

* all standard files from MacOS are accessible to the linux VM
* linux can create any file in `/tmp` as it is not in a 9p mounted filesystem
* name collisions should not be an issue since `/tmp` is anyway a shared namespace

The challenge to this solution is that temporary files come and go. Hence a
service is needed to dynamically mirror MacOS's temporary files using bind
mounts. Moreover, the bind mount must happen before the docker daemon attempts
to bind mount a file, because that would create it instead.

Unfortunately, 9p currently does not provide `inotify` functionality. However,
instead of polling for changes, we can use `docker events` as triggers since
the syncing has to be up-to-date only before a container is started.

