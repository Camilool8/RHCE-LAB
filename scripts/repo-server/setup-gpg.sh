#!/bin/bash
# Usage: setup-gpg.sh
set -euo pipefail

echo "=== Repo server: publish distribution GPG key ==="

WEBROOT=/var/www/html/repo
GPG_DIR=/etc/pki/rpm-gpg

published=0
for key in "$GPG_DIR"/RPM-GPG-KEY-*; do
  [ -f "$key" ] || continue
  cp "$key" "$WEBROOT/$(basename "$key")"
  echo "Published $key -> /repo/$(basename "$key")"
  published=$((published + 1))
done

if [ "$published" -eq 0 ]; then
  echo "WARN: no GPG key found in $GPG_DIR; tasks that reference a key URL may fail"
fi

echo "=== GPG key step complete ==="
