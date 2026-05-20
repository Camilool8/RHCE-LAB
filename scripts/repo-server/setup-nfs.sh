#!/bin/bash
# scripts/repo-server/setup-nfs.sh <subnet_cidr>
# NFS-export the BaseOS/AppStream trees so managed nodes can mount them at
# /mnt/BaseOS and /mnt/AppStream (task 2's file:// repos). NFS services are
# opened on firewalld's `internal` zone (where the lab subnet has been bound
# by base-setup.sh) so the repo server stays defended on its public/NAT
# interface.
set -euo pipefail

SUBNET="${1:?subnet CIDR argument required}"
WEBROOT=/var/www/html/repo

echo "=== Repo server: NFS exports for ${SUBNET} ==="

dnf install -y nfs-utils

cat > /etc/exports <<EOF
${WEBROOT}/BaseOS    ${SUBNET}(ro,sync,no_root_squash)
${WEBROOT}/AppStream ${SUBNET}(ro,sync,no_root_squash)
EOF

# Open NFSv4 + v3 helpers in the internal zone. v4 alone needs only the nfs
# service (port 2049); mountd/rpc-bind cover legacy v3 mount attempts.
for svc in nfs mountd rpc-bind; do
  firewall-cmd --permanent --zone=internal --add-service="$svc" \
    >/dev/null 2>&1 || true
done
firewall-cmd --reload >/dev/null

systemctl enable --now nfs-server
exportfs -rav

echo "=== NFS exports ready (zone: internal) ==="
