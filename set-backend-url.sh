#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./set-backend-url.sh https://YOUR-BACKEND"
  exit 1
fi

URL="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$ROOT_DIR/TEST12/web/config.json"

cat > "$CONFIG_PATH" <<EOF
{
  "api_base_url": "$URL"
}
EOF

echo "Updated: $CONFIG_PATH"
"$ROOT_DIR/make-netlify-zip.sh"

