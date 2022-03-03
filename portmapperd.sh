set -euo pipefail

function active_ports() {
  docker container ls --format "{{.Ports}}" \
    | sed -ne "s/.*:\(.*\)->.*/\1/p"
}

function qemu_do() {
  (echo $*; sleep 0.2) | qemu-monitor
}

function qemu_ports() {
  qemu_do "info usernet" | grep HOST_FORWARD | awk '{ print $4 }'
}

function make_qemu_hostfwds() {
  for i in $ADD; do
    echo "hostfwd_add tcp::$i-:$i"
  done
  for i in $REMOVE; do
    echo "hostfwd_remove tcp::$i"
  done
}

function blacklisted() {
  echo 2222
  echo 2375
}

function watch_docker_expose_ports() {
  (echo; docker events) |  while read line; do
    local DOCKER_PORTS=$((active_ports ; blacklisted) | sort)
    local QEMU_PORTS=$(qemu_ports | sort)

    #echo "###################"
    #echo "state IST"
    #echo "$QEMU_PORTS"
    #echo "state SOLL"
    #echo "$DOCKER_PORTS"
    #echo "###################"
    ADD=$(comm -1 -3 <(echo "$QEMU_PORTS") <(echo "$DOCKER_PORTS"))
    REMOVE=$(comm -2 -3 <(echo "$QEMU_PORTS") <(echo "$DOCKER_PORTS"))
    echo "adding '$ADD'  removing '$REMOVE'"

    CMDS=$(make_qemu_hostfwds)
    if [ -n "$CMDS" ]; then
      #echo $CMDS
      qemu_do "$CMDS"
    fi
  done
}

watch_docker_expose_ports
