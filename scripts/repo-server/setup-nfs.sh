#!/bin/bash
# Repo server: NFS-export the BaseOS/AppStream trees so managed nodes can
# mount them at /mnt/BaseOS and /mnt/AppStream (needed by task 2).
# Arg 1: subnet CIDR allowed to mount (e.g. 192.168.56.0/24).
set -euo pipefail

SUBNET="${1:?subnet CIDR argument required}"
WEBROOT=/var/www/html/repo

echo "=== Repo server: NFS exports for ${SUBNET} ==="

dnf install -y nfs-utils

cat > /etc/exports <<EOF
${WEBROOT}/BaseOS    ${SUBNET}(ro,sync,no_root_squash)
${WEBROOT}/AppStream ${SUBNET}(ro,sync,no_root_squash)
EOF

firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload

systemctl enable --now nfs-server
exportfs -rav

echo "=== NFS exports ready ==="
