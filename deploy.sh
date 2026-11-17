#!/bin/sh
# Cập nhật bản đang chạy trên server: ./deploy.sh
set -eu
cd "$(dirname "$0")"
git pull --ff-only
# Giữ bản đang chạy làm đường lui:
#   docker tag antam-api:truoc antam-api && docker compose up -d --no-build
if docker image inspect antam-api >/dev/null 2>&1; then docker tag antam-api antam-api:truoc; fi
docker compose build --pull     # test đỏ → dừng ở đây, bản cũ vẫn chạy
docker compose up -d
docker compose ps
