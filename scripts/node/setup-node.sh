#!/bin/bash
# Managed node setup: authorize the control node's SSH key, prepare extra
# storage, and mount the BaseOS/AppStream repos from the repo server.
# Arg 1: repo server IP.
set -euo pipefail

REPO_IP="${1:?repo server IP argument required}"

echo "=== Managed node setup: $(hostname) ==="

# --- Ansible-managed-node prerequisites ---
dnf install -y python3 lvm2 nfs-utils

# --- Authorize the RH294-LAB key for student (uploaded to /tmp by Vagrant) ---
install -d -m 700 -o student -g student /home/student/.ssh
touch /home/student/.ssh/authorized_keys
cat /tmp/RH294-LAB.pub >> /home/student/.ssh/authorized_keys
sort -u /home/student/.ssh/authorized_keys -o /home/student/.ssh/authorized_keys
chown student:student /home/student/.ssh/authorized_keys
chmod 600 /home/student/.ssh/authorized_keys
restorecon -R /home/student/.ssh 2>/dev/null || true

# --- VG 'research' on /dev/sdc (task 16). /dev/sdb left raw for task 17. ---
if [ -b /dev/sdc ]; then
  if ! vgs research &>/dev/null; then
    pvcreate -y /dev/sdc
    vgcreate research /dev/sdc
    echo "Created volume group 'research' on /dev/sdc"
  fi
else
  echo "WARN: /dev/sdc not present — VG 'research' not created"
fi

# --- Mount BaseOS/AppStream from the repo server at /mnt (task 2) ---
mkdir -p /mnt/BaseOS /mnt/AppStream
for share in BaseOS AppStream; do
  fstab_line="${REPO_IP}:/var/www/html/repo/${share} /mnt/${share} nfs ro,_netdev 0 0"
  grep -qF " /mnt/${share} nfs " /etc/fstab \
    || echo "$fstab_line" >> /etc/fstab
done
mount -a || echo "WARN: NFS mount deferred (repo server may not be ready yet)"

echo "=== Managed node setup complete: $(hostname) ==="
