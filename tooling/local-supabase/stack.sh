#!/bin/sh
set -eu
# Run only inside the newly imported PlaySpotAcceptance20261030 distribution.
# The Windows wrapper verifies its registry BasePath before calling this script.
export DOCKER_HOST=unix:///run/playspot-docker.sock
export DOCKER_CONFIG=/opt/playspot-acceptance/docker-client
root=/var/lib/playspot-docker
project=/opt/playspot-acceptance/project
cli=/opt/playspot-tools/supabase
[ "$(id -u)" = 0 ] || { echo 'Dedicated guest root required'; exit 1; }
[ "$($cli --version)" = 2.122.0 ] || { echo 'Pinned CLI 2.122.0 required'; exit 1; }
[ "$(docker info --format '{{.DockerRootDir}}')" = "$root" ] || { echo 'Daemon storage isolation not verified'; exit 1; }
[ -f "$project/supabase/config.toml" ] || { echo 'Prepared config missing'; exit 1; }
case "${1:-verify}" in
  start)
    if ! docker network inspect playspot-acceptance-internal >/dev/null 2>&1; then
      docker network create --internal --driver bridge -o com.docker.network.bridge.host_binding_ipv4=127.0.0.1 playspot-acceptance-internal >/dev/null
    fi
    [ "$(docker network inspect --format '{{.Internal}}' playspot-acceptance-internal)" = true ] || exit 1
    [ "$(docker network inspect --format '{{index .Options "com.docker.network.bridge.host_binding_ipv4"}}' playspot-acceptance-internal)" = 127.0.0.1 ] || exit 1
    # Image pulls happen in the isolated guest daemon; running services have no external route.
    mkdir -p /opt/playspot-acceptance/private; chmod 700 /opt/playspot-acceptance/private
    umask 077
    $cli start --workdir "$project" --network-id playspot-acceptance-internal > /opt/playspot-acceptance/private/start.log 2>&1
    echo "Services started; run verify before connecting clients"
    ;;
  stop) $cli stop --workdir "$project" --project-id playspot-acceptance-20261030 ;;
  verify)
    docker info --format 'Daemon={{.ID}} root={{.DockerRootDir}}'
    docker network inspect --format 'Internal={{.Internal}} Binding={{index .Options "com.docker.network.bridge.host_binding_ipv4"}}' playspot-acceptance-internal
    docker ps --format '{{.Names}} {{.Ports}}'
    # Status includes credentials; never print it in a report or terminal.
    ;;
  *) echo 'Use start, stop, or verify'; exit 1 ;;
esac
