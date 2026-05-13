#!/usr/bin/env bash
set -euo pipefail

VPS="root@177.7.51.7"
REMOTE_DIR="/root/gfm_mw"
IMAGE="gfm-middleware:latest"

# The prod postgres data volume was initialized with POSTGRES_USER=gfm and
# POSTGRES_DB=gfm. Changing either of these in .env breaks the app even though
# postgres still reports healthy (pg_isready does not check that the DB exists).
# See SESSION_CONTEXT 2026-05-13 incident.
echo "==> Pre-flight: validating .env..."
test -f .env || { echo "ERROR: .env not found in $(pwd)"; exit 1; }
grep -q "^POSTGRES_USER=gfm$" .env || { echo "ERROR: POSTGRES_USER must be 'gfm' (matches existing data volume)"; exit 1; }
grep -q "^POSTGRES_DB=gfm$"   .env || { echo "ERROR: POSTGRES_DB must be 'gfm' (matches existing data volume)"; exit 1; }

echo "==> Building image for linux/amd64..."
docker build --platform linux/amd64 --target runtime -t "$IMAGE" .

echo "==> Transferring image to VPS..."
docker save "$IMAGE" | ssh "$VPS" docker load

echo "==> Copying compose file and .env..."
scp docker-compose.prod.yml "$VPS:$REMOTE_DIR/"
scp .env "$VPS:$REMOTE_DIR/"

# --no-deps prevents compose from recreating postgres/redis just because the
# .env file changed. The app picks up the new image; the DB stays warm.
echo "==> Restarting app on VPS (postgres + redis untouched)..."
ssh "$VPS" "cd $REMOTE_DIR && docker compose -f docker-compose.prod.yml up -d --no-deps --force-recreate app"

echo "==> Waiting for app to accept connections..."
for i in 1 2 3 4 5 6 7 8 9 10; do
  code=$(ssh "$VPS" "curl -s -o /dev/null -w '%{http_code}' http://localhost:3002/ping" || true)
  if [ "$code" = "200" ]; then
    echo "==> Healthy (http=200 on attempt $i)"
    exit 0
  fi
  echo "    attempt $i → http=$code, retrying..."
  sleep 2
done
echo "ERROR: app did not return 200 within 20s"
exit 1
