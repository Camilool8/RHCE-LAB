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

# --- VG 'research' on the second extra disk (task 16).
# The device name depends on the Vagrant provider:
#   VirtualBox/Parallels      -> /dev/sdc (SCSI/SATA)
#   libvirt                   -> /dev/vdc (virtio)
#   VMware Fusion (Apple Si)  -> /dev/nvme0n3 (NVMe; nvme0n1 = root, n2 = first extra)
# The first extra disk is intentionally left raw for task 17.
RESEARCH_DISK=""
for d in /dev/sdc /dev/vdc /dev/nvme0n3; do
  if [ -b "$d" ]; then RESEARCH_DISK="$d"; break; fi
done

if [ -n "$RESEARCH_DISK" ]; then
  if ! vgs research &>/dev/null; then
    pvcreate -y "$RESEARCH_DISK"
    vgcreate research "$RESEARCH_DISK"
    echo "Created volume group 'research' on $RESEARCH_DISK"
  fi
else
  echo "WARN: no extra disk found for VG 'research' (checked /dev/sdc, /dev/vdc, /dev/nvme0n3)"
fi

# --- Mount BaseOS/AppStream from the repo server at /mnt (task 2) ---
# systemd automount: mounts on first access (e.g. dnf --enablerepo=) instead
# of at boot. If the repo server is briefly unreachable, the node still boots
# cleanly — the mount activates whenever it's first touched. RHEL 9 'Managing
# file systems' Ch. 19 covers this pattern.
mkdir -p /mnt/BaseOS /mnt/AppStream
NFS_OPTS="x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.device-timeout=10"
NFS_OPTS="${NFS_OPTS},_netdev,nofail,ro,vers=4.2,noatime"
for share in BaseOS AppStream; do
  fstab_line="${REPO_IP}:/var/www/html/repo/${share} /mnt/${share} nfs ${NFS_OPTS} 0 0"
  # Replace any prior lab entry for this mount point so option changes apply.
  sed -i "\| /mnt/${share} nfs |d" /etc/fstab
  echo "$fstab_line" >> /etc/fstab
done
systemctl daemon-reload
# Activate the .automount units now — actual NFS contact is deferred to
# first access of /mnt/{BaseOS,AppStream}.
systemctl start "$(systemd-escape --suffix=automount --path /mnt/BaseOS)" \
                "$(systemd-escape --suffix=automount --path /mnt/AppStream)" \
  2>/dev/null || true

echo "=== Managed node setup complete: $(hostname) ==="
