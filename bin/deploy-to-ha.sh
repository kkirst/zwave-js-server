#!/bin/bash
# Build the @zwave-js/server fork and restart HA's zwave-js-ui to pick up
# the new dist-cjs / dist-esm bind-mounts. See deploy-to-ha.sh in the
# zwave-js-dev repo for the equivalent zwave-js-side flow.
set -euo pipefail
cd "$(dirname "$0")/.."

COMPOSE_DIR="/opt/home-assistant"
COMPOSE="$COMPOSE_DIR/docker-compose.yaml"
OVERRIDE="$COMPOSE_DIR/docker-compose.override.yaml"
# Both files must be explicitly listed when invoking docker compose with -f;
# auto-loading of *.override.yaml does NOT happen when -f is used.
COMPOSE_ARGS=(-f "$COMPOSE" -f "$OVERRIDE")

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }

step "build (tsc + esm2cjs)"
npm run build

step "verify dist-cjs + dist-esm exist"
for d in dist-cjs dist-esm; do
  if [ ! -d "$d" ]; then
    echo "  !!! missing $d — aborting"
    exit 1
  fi
done
echo "  both build dirs present"

step "verify docker-compose.override.yaml has our bind-mounts"
if ! grep -q "zwave-js-server-dev/dist-cjs" "$OVERRIDE"; then
  echo "  !!! $OVERRIDE missing zwave-js-server bind-mounts — refusing to deploy"
  exit 1
fi
echo "  override file references our fork"

step "current mount status"
EXISTING=$(docker inspect zwave-js-ui --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{println}}{{end}}' 2>/dev/null | grep zwave-js-server-dev || true)
if [ -z "$EXISTING" ]; then
  echo "  no server-fork bind-mounts in current container — will force-recreate"
  RECREATE=1
else
  echo "  server-fork bind-mounts already present:"
  echo "$EXISTING" | sed 's/^/    /'
  RECREATE=0
fi

step "apply"
if [ "$RECREATE" = 1 ]; then
  docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate --no-deps zwave-js-ui
else
  docker compose "${COMPOSE_ARGS[@]}" restart zwave-js-ui
fi
sleep 4

step "verify container is up + our mounts active"
docker inspect zwave-js-ui --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{println}}{{end}}' | grep zwave-js-server-dev | sed 's/^/  /'

step "tail HA's zwave-js-ui log"
docker logs zwave-js-ui --tail 10

step "done"
