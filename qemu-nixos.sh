#!/usr/bin/env bash
set -eux -o pipefail

COMMAND=$1
case "$COMMAND" in
  --start)
    qemu-nixos
    ;;
  --set-ssh)
    SETUP_PW=asdf
    qemu-type "passwd"; sleep 1
    qemu-type $SETUP_PW; sleep 1
    qemu-type $SETUP_PW; sleep 1
    PASSWORD=$SETUP_PW ssh-copy-id-password vm
    ;;
  --install)
    scp uefi-install.sh {hardware-,}configuration.nix nixos@vm:
    BEFORE=$(date)
    ssh nixos@vm "sudo bash ./uefi-install.sh"
    DONE=$(date)
    echo "BEFORE: $BEFORE"
    echo "DONE:   $DONE"
    ;;

  --fresh-vm)
    qemu-nixos --fresh
    ;;

  --full-setup)
    waitForSsh vm
    $0 --set-ssh
    $0 --install
    ;;

  --fresh)
    $0 --fresh-vm &
    sleep 10
    $0 --full-setup
    qemu-pipe <<< "quit"
    echo "#############################################"
    echo "#####  Installation completed  ##############"
    echo "#############################################"
    $0 --start
    ;;
esac
