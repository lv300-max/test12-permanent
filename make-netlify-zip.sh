#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WEB_DIR="$ROOT_DIR/TEST12/web"

ZIP_LATEST_PATH="$ROOT_DIR/netlify-upload.zip"

next_seq=1
for f in "$ROOT_DIR"/netlify-upload-*.zip; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f")"
  n="${base#netlify-upload-}"
  n="${n%.zip}"
  [[ "$n" =~ ^[0-9]+$ ]] || continue
  n=$((10#$n))
  if ((n >= next_seq)); then
    next_seq=$((n + 1))
  fi
done

ZIP_NUMBERED_PATH="$ROOT_DIR/netlify-upload-$(printf '%03d' "$next_seq").zip"

rm -f "$ZIP_LATEST_PATH"
(cd "$WEB_DIR" && zip -r "$ZIP_NUMBERED_PATH" index.html privacy.html moneyhopper-privacy.html submit.html config.json netlify.toml _redirects _headers assets -x "*/.DS_Store" -x ".DS_Store" >/dev/null)
cp -f "$ZIP_NUMBERED_PATH" "$ZIP_LATEST_PATH"

echo "Wrote: $ZIP_NUMBERED_PATH"
echo "Latest: $ZIP_LATEST_PATH"
