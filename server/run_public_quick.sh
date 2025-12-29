#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$ROOT_DIR/server"

PORT="${PORT:-8787}"
STATE_PATH="${TEST12_STATE_PATH:-$SERVER_DIR/data/state.json}"
ADMIN_TOKEN="${TEST12_ADMIN_TOKEN:-change-me}"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared not found. Install with: brew install cloudflared"
  exit 1
fi

mkdir -p "$(dirname "$STATE_PATH")"

SERVER_LOG="$SERVER_DIR/.public_server.log"
TUNNEL_LOG="$SERVER_DIR/.public_tunnel.log"

: > "$SERVER_LOG"
: > "$TUNNEL_LOG"

echo "Starting server on :$PORT (state: $STATE_PATH)"
cd "$SERVER_DIR"
nohup env PORT="$PORT" TEST12_STATE_PATH="$STATE_PATH" TEST12_ADMIN_TOKEN="$ADMIN_TOKEN" node index.js >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$SERVER_DIR/.server_pid"

sleep 1

echo "Starting public tunnel..."
nohup cloudflared tunnel --url "http://localhost:$PORT" --no-autoupdate >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!
echo "$TUNNEL_PID" > "$SERVER_DIR/.tunnel_pid"

echo "Waiting for public URL..."
URL=""
for _ in $(seq 1 60); do
  URL="$(grep -Eo "https://[a-z0-9-]+\\.trycloudflare\\.com" "$TUNNEL_LOG" | tail -n 1 || true)"
  if [[ -n "$URL" ]]; then
    break
  fi
  sleep 1
done
     
if [[ -z "$URL" ]]; then
  echo "Could not find a trycloudflare URL. Check logs:"
  echo "  $SERVER_LOG"
  echo "  $TUNNEL_LOG"
  exit 1
fi

echo "Public backend URL:"
echo "  $URL"

CONFIG_PATH="$ROOT_DIR/TEST12/web/config.json"
cat > "$CONFIG_PATH" <<EOF
{
  "api_base_url": "$URL"
}
EOF

echo "Updated: $CONFIG_PATH"

"$ROOT_DIR/make-netlify-zip.sh"

echo ""
echo "Next:"
echo "1) Upload netlify-upload.zip to Netlify (drag/drop)."
echo "2) Keep this terminal running (the tunnel must stay up)."
