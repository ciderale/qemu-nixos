#!/usr/bin/env bash
set -eux -o pipefail

COMMAND=$1
case "$COMMAND" in
  --start)
    qemu-nixos
    ;;


  --fresh)
    qemu-nixos --fresh &
    sleep 10
    waitForSsh vm
    $0 --set-ssh
    $0 --install
    qemu-pipe <<< "quit"
    echo "#############################################"
    echo "#####  Installation completed  ##############"
    echo "#############################################"
    $0 --start
    ;;

  --set-ssh)
    SETUP_PW=asdf
    qemu-type "passwd"; sleep 1
    qemu-type $SETUP_PW; sleep 1
    qemu-type $SETUP_PW; sleep 1
    PASSWORD=$SETUP_PW ssh-copy-id-password vm
    ;;

  --install)
    scp vm-partitioning.sh vm-install.sh nixos@vm:
    ssh nixos@vm "sudo bash ./vm-partitioning.sh"
    ssh nixos@vm "sudo bash ./vm-install.sh"
    ;;

esac
