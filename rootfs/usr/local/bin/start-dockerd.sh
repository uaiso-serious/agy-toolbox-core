#!/bin/bash
# Inicia o dockerd rootless (DinD) como o usuário atual, sem sudo.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/docker-$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
SOCK="$XDG_RUNTIME_DIR/docker.sock"
LOG="$XDG_RUNTIME_DIR/dockerd.log"
if docker -H "unix://$SOCK" info >/dev/null 2>&1; then
  echo "$SOCK"; exit 0
fi
nohup dockerd-rootless.sh --host="unix://$SOCK" \
  --storage-driver="${DOCKERD_STORAGE_DRIVER:-overlay2}" \
  >"$LOG" 2>&1 &
for _ in $(seq 1 30); do
  docker -H "unix://$SOCK" info >/dev/null 2>&1 && { echo "$SOCK"; exit 0; }
  sleep 1
done
echo "dockerd não iniciou; veja $LOG" >&2
exit 1
