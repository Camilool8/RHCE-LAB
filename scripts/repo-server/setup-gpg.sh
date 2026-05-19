#!/bin/bash
# Repo server: publish the AlmaLinux GPG key over HTTP.
# (The key also already exists on every AlmaLinux node at the path
#  task 2 expects: /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9.)
set -euo pipefail

echo "=== Repo server: publish GPG key ==="

KEY=/etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9
if [ -f "$KEY" ]; then
  cp "$KEY" /var/www/html/repo/RPM-GPG-KEY-AlmaLinux-9
  echo "Published $KEY -> /repo/RPM-GPG-KEY-AlmaLinux-9"
else
  echo "WARN: $KEY not found on repo server"
fi

echo "=== GPG key step complete ==="
