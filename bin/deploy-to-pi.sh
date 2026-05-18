#!/bin/bash
# Build @zwave-js/server fork and rsync the dist-cjs + dist-esm to the Pi's
# vendored copy at /opt/zwave-js-server/node_modules/@zwave-js/server/, then
# restart zwave-js-server.service. Mirrors the zwave-js-dev/deploy-to-pi.sh
# but for the WS-server package.
set -euo pipefail
cd "$(dirname "$0")/.."

PI=matter-hub
REMOTE_BASE=/opt/zwave-js-server/node_modules/@zwave-js/server

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }

step "build (tsc + esm2cjs)"
npm run build

step "rsync dist-cjs + dist-esm to the Pi"
for d in dist-cjs dist-esm; do
  printf '  %-10s → %s/%s/\n' "$d" "$PI:$REMOTE_BASE" "$d"
  rsync -a --delete "$d/" "$PI:$REMOTE_BASE/$d/"
done

step "restart zwave-js-server on the Pi"
ssh "$PI" 'systemctl restart zwave-js-server && sleep 4 && systemctl is-active zwave-js-server'

step "tail Pi log"
ssh "$PI" 'journalctl -u zwave-js-server -n 8 --no-pager'

step "done"
