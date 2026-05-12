#!/usr/bin/env bash
set -euo pipefail

VPS="root@177.7.51.7"
REMOTE_DIR="/root/gfm_mw"
IMAGE="gfm-middleware:latest"

echo "==> Building image for linux/amd64..."
docker build --platform linux/amd64 --target runtime -t "$IMAGE" .

echo "==> Transferring image to VPS..."
docker save "$IMAGE" | ssh "$VPS" docker load

echo "==> Copying compose file and .env..."
scp docker-compose.prod.yml "$VPS:$REMOTE_DIR/"
scp .env "$VPS:$REMOTE_DIR/"

echo "==> Restarting app on VPS..."
ssh "$VPS" "cd $REMOTE_DIR && docker compose -f docker-compose.prod.yml up -d --force-recreate app"

echo "==> Done. Checking health..."
sleep 3
ssh "$VPS" "curl -s http://localhost:3002/ping"
echo ""
