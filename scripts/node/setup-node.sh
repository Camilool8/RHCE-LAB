#!/bin/bash
# scripts/node/setup-node.sh
#
# Configure a managed node:
#   * point dnf at the lab's offline mirror so the rest of provisioning
#     (and all subsequent task work) needs zero internet
#   * lay down SSH keys for control-node access as 'student'
#   * pre-create the research VG on the second extra disk
#   * NFS-automount the lab mirror at /mnt/{BaseOS,AppStream} (the path
#     the student's task 2 will write `baseurl: file:///...` against)

set -euo pipefail

REPO_IP="${1:?repo server IP argument required}"

echo "=== Managed node setup: $(hostname) ==="

# ---- 1. Point dnf at the lab mirror (HTTP) and disable vendor online repos ----
#
# Two repo URLs are simultaneously valid:
#   * file:///mnt/BaseOS/  — NFS automount; this is what task 2 has the
#     student write into /etc/yum.repos.d/BaseOS.repo themselves.
#   * http://<repo>/repo/BaseOS/  — direct HTTP; what we use here because
#     it has no dependency on the automount being primed before dnf runs.
#
# Task 2's deliverable stays in /etc/yum.repos.d/BaseOS.repo. The lab's
# own offline-bootstrap repo lives in /etc/yum.repos.d/lab-offline.repo
# so the two never collide.

GPG_KEY=$(find /etc/pki/rpm-gpg -maxdepth 1 -type f -name 'RPM-GPG-KEY-*' 2>/dev/null | sort | head -1)
GPG_KEY_LINE="gpgcheck=0"
if [ -n "$GPG_KEY" ]; then
    GPG_KEY_LINE="gpgcheck=1
gpgkey=file://${GPG_KEY}"
fi

cat > /etc/yum.repos.d/lab-offline.repo <<EOF
# Managed by scripts/node/setup-node.sh — do not edit by hand.
# Points the node at the lab's offline HTTP mirror as the only dnf source.
# Task 2's BaseOS.repo / AppStream.repo (file:///mnt/...) coexists with this.

[lab-baseos]
name=Lab BaseOS (offline mirror via HTTP)
baseurl=http://${REPO_IP}/repo/BaseOS/
${GPG_KEY_LINE}
enabled=1

[lab-appstream]
name=Lab AppStream (offline mirror via HTTP)
baseurl=http://${REPO_IP}/repo/AppStream/
${GPG_KEY_LINE}
enabled=1
EOF

# Disable every vendor online repo so the lab is genuinely offline by default.
# Files remain on disk; a student can re-enable any of them with
# `dnf --enablerepo=baseos install foo` for an explicit online test.
for f in /etc/yum.repos.d/almalinux-*.repo \
         /etc/yum.repos.d/rocky-*.repo \
         /etc/yum.repos.d/redhat-*.repo \
         /etc/yum.repos.d/centos-*.repo; do
    [ -f "$f" ] || continue
    sed -i 's/^enabled=1$/enabled=0/' "$f" || true
done

dnf -q clean all >/dev/null 2>&1 || true

# ---- 2. Bootstrap packages from the lab mirror ----
dnf install -y python3 lvm2 nfs-utils

# ---- 3. SSH keys for the 'student' user (control → managed node) ----
install -d -m 700 -o student -g student /home/student/.ssh
touch /home/student/.ssh/authorized_keys
cat /tmp/RH294-LAB.pub >> /home/student/.ssh/authorized_keys
sort -u /home/student/.ssh/authorized_keys -o /home/student/.ssh/authorized_keys
chown student:student /home/student/.ssh/authorized_keys
chmod 600 /home/student/.ssh/authorized_keys
restorecon -R /home/student/.ssh 2>/dev/null || true

# ---- 4. Pre-create the 'research' VG on the second extra disk ----
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

# ---- 5. NFS automount of the lab mirror — what task 2 will use ----
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
