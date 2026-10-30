#!/bin/sh
set -eu
# Foreground daemon: keep its terminal/session alive. Run only in the dedicated
# imported distribution after the Windows registry BasePath check.
mkdir -p /var/lib/playspot-docker /run/playspot-docker
exec dockerd --data-root /var/lib/playspot-docker \
 --exec-root /run/playspot-docker --pidfile /run/playspot-docker.pid \
 --host unix:///run/playspot-docker.sock
