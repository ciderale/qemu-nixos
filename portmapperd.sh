set -euo pipefail

VERBOSE=${VERBOSE:-1}
STATIC_PORTS="2222 2375"

STATIC_PORTS_GREP=$(echo $STATIC_PORTS | sed -e 's/\([^ ]*\)/^\1$/g;s/ /\\|/g')
QEMU_DELAY=0.2

function debug() {
  LEVEL=$1; shift
  if [ $LEVEL -lt $VERBOSE ]; then
    echo "${@}"
  fi
}

function active_ports() {
  docker container ls --format "{{.Ports}}" \
    | tr , '\n' \
    | sed -ne "s/.*:\(.*\)->.*/\1/p" \
    | sort | uniq
}

function qemu_do() {
  (echo "$*"; sleep $QEMU_DELAY) | qemu-monitor
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

function static_ports() {
  grep -v "$STATIC_PORTS_GREP"
}

function watch_docker_expose_ports() {
  debug 0 "Starting partmapperd (ignoring $STATIC_PORTS_GREP)"
  (echo; docker events) | while read line; do
    local DOCKER_PORTS=$(active_ports | sort)
    local QEMU_PORTS=$(qemu_ports | static_ports | sort)

    debug 1 "###################"
    debug 1 "CURRENT state:"
    debug 1 "$QEMU_PORTS"
    debug 1 "TARGET state:"
    debug 1 "$DOCKER_PORTS"
    debug 1 "###################"

    ADD=$(comm -1 -3 <(echo "$QEMU_PORTS") <(echo "$DOCKER_PORTS"))
    REMOVE=$(comm -2 -3 <(echo "$QEMU_PORTS") <(echo "$DOCKER_PORTS"))
    debug 1 "adding '$ADD'  removing '$REMOVE'"

    CMDS=$(make_qemu_hostfwds)
    if [ -n "$CMDS" ]; then
      debug 0 $CMDS
      qemu_do "$CMDS"
      debug 1 "Forarded ports: $(qemu_ports|xargs)"
    fi
  done
}

watch_docker_expose_ports
