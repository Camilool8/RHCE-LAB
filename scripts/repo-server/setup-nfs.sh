#!/bin/bash
# Usage: setup-nfs.sh <subnet_cidr>
set -euo pipefail

SUBNET="${1:?subnet CIDR argument required}"
WEBROOT=/var/www/html/repo

echo "=== Repo server: NFS exports for ${SUBNET} ==="

dnf install -y nfs-utils

cat > /etc/exports <<EOF
${WEBROOT}/BaseOS    ${SUBNET}(ro,sync,no_root_squash)
${WEBROOT}/AppStream ${SUBNET}(ro,sync,no_root_squash)
EOF

for svc in nfs mountd rpc-bind; do
  firewall-cmd --permanent --zone=internal --add-service="$svc" >/dev/null 2>&1 || true
done
firewall-cmd --reload >/dev/null

systemctl enable --now nfs-server
exportfs -rav

echo "=== NFS exports ready (zone: internal) ==="
