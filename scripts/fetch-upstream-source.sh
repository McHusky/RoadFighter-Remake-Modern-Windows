#!/usr/bin/env sh
set -eu
URL='https://gitlab.com/coringao/roadfighter/-/archive/1.0.0/roadfighter-1.0.0.zip'
OUT="$(dirname "$0")/../roadfighter-upstream-1.0.0.zip"
if command -v curl >/dev/null 2>&1; then
  curl -L "$URL" -o "$OUT"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$OUT" "$URL"
else
  echo 'Need curl or wget.' >&2
  exit 1
fi
echo "Saved upstream source archive to $OUT"
