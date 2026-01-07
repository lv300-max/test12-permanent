#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ZIP_PATH="$ROOT_DIR/netlify-upload.zip"
WEB_DIR="$ROOT_DIR/TEST12/web"

rm -f "$ZIP_PATH"
(cd "$WEB_DIR" && zip -r "$ZIP_PATH" index.html privacy.html submit.html config.json netlify.toml _redirects _headers assets -x "*/.DS_Store" -x ".DS_Store" >/dev/null)

echo "Wrote: $ZIP_PATH"
