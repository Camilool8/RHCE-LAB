#!/bin/bash
# Usage: setup-node.sh <repo_ip>
set -euo pipefail

REPO_IP="${1:?repo server IP argument required}"

echo "=== Managed node setup: $(hostname) ==="

dnf install -y python3 lvm2 nfs-utils

install -d -m 700 -o student -g student /home/student/.ssh
touch /home/student/.ssh/authorized_keys
cat /tmp/RH294-LAB.pub >> /home/student/.ssh/authorized_keys
sort -u /home/student/.ssh/authorized_keys -o /home/student/.ssh/authorized_keys
chown student:student /home/student/.ssh/authorized_keys
chmod 600 /home/student/.ssh/authorized_keys
restorecon -R /home/student/.ssh 2>/dev/null || true

find_research_disk() {
  for d in /dev/sdc /dev/vdc /dev/nvme0n3; do
    [ -b "$d" ] && { echo "$d"; return 0; }
  done
  return 1
}

if research_disk=$(find_research_disk); then
  if ! vgs research &>/dev/null; then
    pvcreate -y "$research_disk"
    vgcreate research "$research_disk"
    echo "Created volume group 'research' on $research_disk"
  fi
else
  echo "WARN: no extra disk found for VG 'research' (checked /dev/sdc, /dev/vdc, /dev/nvme0n3)"
fi

mkdir -p /mnt/BaseOS /mnt/AppStream
NFS_OPTS="x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.device-timeout=10"
NFS_OPTS="${NFS_OPTS},_netdev,nofail,ro,vers=4.2,noatime"
for share in BaseOS AppStream; do
  fstab_line="${REPO_IP}:/var/www/html/repo/${share} /mnt/${share} nfs ${NFS_OPTS} 0 0"
  sed -i "\| /mnt/${share} nfs |d" /etc/fstab
  echo "$fstab_line" >> /etc/fstab
done
systemctl daemon-reload
systemctl start "$(systemd-escape --suffix=automount --path /mnt/BaseOS)" \
                "$(systemd-escape --suffix=automount --path /mnt/AppStream)" \
  2>/dev/null || true

echo "=== Managed node setup complete: $(hostname) ==="
