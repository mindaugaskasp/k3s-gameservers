#!/usr/bin/env bash
# Center-screen message to everyone online, text passed as-is:
#   ./broadcast.sh "Hello, world" [--size 28] [--fadetime 15]
set -euo pipefail
exec kubectl -n "${NAMESPACE:-games}" exec "${POD:-valheim-0}" -c gameserver -- \
  python3 /etc/valheim-hooks/rcon-broadcast.py "$@"
