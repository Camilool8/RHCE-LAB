#!/bin/bash
# scripts/repo-server/setup-repos.sh
#
# Build a fully offline package mirror for the lab.
#
# Strategy: use the AlmaLinux online mirrors during repo-server provisioning
# (this is the *only* moment internet is required) to `dnf reposync` the
# BaseOS and AppStream repositories — including comps, GPG checks, and
# modular metadata — into /var/www/html/repo. After this completes, the
# lab is fully offline-capable: stop internet, run `vagrant up` of the
# rest of the lab, do tasks 1-18 without ever touching a public mirror.
#
# Idempotent: on subsequent provisions, only delta packages are downloaded.
# Override REPO_PACKAGE_THRESHOLD to relax the "mirror complete enough"
# heuristic that lets us skip work on re-provision.
set -euo pipefail

WEBROOT=/var/www/html/repo
REPO_PACKAGE_THRESHOLD="${REPO_PACKAGE_THRESHOLD:-500}"

echo "=== Repo server: building offline BaseOS + AppStream mirror ==="

# ---- Mount the dedicated mirror disk at $WEBROOT -----------------------------
#
# BaseOS + AppStream is ~28 GB today and grows with every upstream release.
# Some box variants (notably almalinux/9 on vmware_desktop arm64) ship a
# ~20 GB root disk, which fills up partway through AppStream and surfaces
# as `Curl error (23): Failed writing received data to disk/application`
# on the larger packages (dotnet-sdk-dbg etc.).
#
# config.yaml attaches an extra_disk to repo_server; we format it XFS on
# first boot and mount it at $WEBROOT. If no extra disk is present we fall
# back to the root filesystem so older configs still work.
prepare_mirror_disk() {
    local mountpoint="$1"
    mkdir -p "$mountpoint"

    # Already mounted (re-provision after first install) — nothing to do.
    if mountpoint -q "$mountpoint"; then
        echo "Mirror disk already mounted at ${mountpoint}"
        return 0
    fi

    local dev=""
    # Vagrant exposes the first extra disk as /dev/sdb (VirtualBox, Parallels),
    # /dev/vdb (libvirt), or /dev/nvme0n2 (VMware Fusion + bus_type=nvme; the
    # repo VM's primary is on /dev/sda, so NVMe extras start at nvme0n2 —
    # the same offset setup-node.sh assumes when it probes /dev/nvme0n3 for
    # the second extra on managed nodes).
    #
    # Skip any candidate that already has a mounted filesystem (root disk on
    # a box variant where naming overlaps) or is smaller than the 40 GB extra
    # disk we asked for (phantom controllers, etc.).
    local min_bytes=$((30 * 1024 * 1024 * 1024))   # 30 GiB safety floor
    for candidate in /dev/sdb /dev/vdb /dev/nvme0n2; do
        [ -b "$candidate" ] || continue
        if lsblk -no MOUNTPOINTS "$candidate" 2>/dev/null \
                | awk 'NF' | head -1 | grep -q .; then
            continue
        fi
        local size
        size=$(lsblk -bdn -o SIZE "$candidate" 2>/dev/null || echo 0)
        [ -n "$size" ] && [ "$size" -ge "$min_bytes" ] || continue
        dev="$candidate"
        break
    done

    if [ -z "$dev" ]; then
        echo "INFO: no dedicated mirror disk found; using root filesystem"
        return 0
    fi

    if ! blkid "$dev" >/dev/null 2>&1; then
        echo "Mirror disk: formatting ${dev} as XFS"
        mkfs.xfs -q -L repo-mirror "$dev"
    fi

    local uuid
    uuid=$(blkid -s UUID -o value "$dev")
    [ -n "$uuid" ] || { echo "ERROR: ${dev} has no UUID after mkfs"; return 1; }

    # Replace any existing fstab entry for this mountpoint to keep idempotent.
    sed -i "\| ${mountpoint} xfs |d" /etc/fstab
    echo "UUID=${uuid} ${mountpoint} xfs defaults,nofail 0 0" >> /etc/fstab

    mount "$mountpoint"

    # SELinux: the mountpoint stays /var/www/html/repo (httpd_sys_content_t),
    # but a freshly-mounted XFS volume has no labels yet — fix that.
    restorecon -R "$mountpoint" 2>/dev/null || true

    echo "Mirror disk ${dev} (UUID=${uuid}) mounted at ${mountpoint}"
}

prepare_mirror_disk "$WEBROOT"

dnf install -y httpd createrepo_c dnf-plugins-core

# Discover the upstream repoids on whatever box variant we booted. AlmaLinux
# 9 ships them as 'baseos' / 'appstream', RHEL 9 as 'rhel-9-for-*-baseos-rpms'.
find_repoid() {
    local pattern="$1" id
    id=$(dnf repolist --all 2>/dev/null \
            | awk -v p="$pattern" 'NR>1 && tolower($1) ~ tolower(p){print $1; exit}')
    [ -n "$id" ] && { echo "$id"; return 0; }
    return 1
}

BASEOS_ID=$(find_repoid '^baseos|baseos-rpms$') || BASEOS_ID="baseos"
APPSTREAM_ID=$(find_repoid '^appstream|appstream-rpms$') || APPSTREAM_ID="appstream"
echo "Upstream repoids: BaseOS=${BASEOS_ID}  AppStream=${APPSTREAM_ID}"

mirror_repo() {
    local repo_id="$1" dst="$2" label="$3"
    mkdir -p "$dst"

    local existing
    existing=$(find "$dst" -name '*.rpm' 2>/dev/null | wc -l)
    if [ -f "$dst/repodata/repomd.xml" ] && [ "$existing" -ge "$REPO_PACKAGE_THRESHOLD" ]; then
        echo "${label}: already mirrored (${existing} rpms + repodata). Refreshing delta only."
    else
        echo "${label}: full mirror starting (this takes 5-20 min over a fast link)."
    fi

    # --download-metadata: pull repomd/primary/filelists/modules.yaml/etc.
    # --downloadcomps:     pull comps.xml (package groups, e.g. 'RPM Development Tools').
    # --norepopath:        write directly into $dst (no $repo_id/ wrapper dir).
    # --delete:            drop local rpms that the upstream no longer ships.
    # --gpgcheck:          refuse to mirror unsigned packages.
    if ! dnf reposync \
            --repoid="$repo_id" \
            --download-metadata \
            --downloadcomps \
            --norepopath \
            --delete \
            --gpgcheck \
            -p "$dst" 2>&1 | tail -5; then
        echo "WARN: ${label}: reposync exited non-zero. Mirror may be incomplete."
    fi

    # If --download-metadata missed something (older dnf, or upstream quirk),
    # regenerate. Re-running createrepo_c on top of upstream metadata is a
    # last resort: it drops modular data, so we only do it as a fallback.
    if [ ! -f "$dst/repodata/repomd.xml" ]; then
        echo "${label}: upstream repodata missing; regenerating with createrepo_c"
        if [ -f "$dst/comps.xml" ]; then
            createrepo_c -g comps.xml "$dst"
        else
            createrepo_c "$dst"
        fi
    fi

    local final
    final=$(find "$dst" -name '*.rpm' 2>/dev/null | wc -l)
    echo "${label}: ${final} packages on disk; repodata stamp $(stat -c '%y' "$dst/repodata/repomd.xml" 2>/dev/null || echo MISSING)"
}

mirror_repo "$BASEOS_ID"    "$WEBROOT/BaseOS"    "BaseOS"
mirror_repo "$APPSTREAM_ID" "$WEBROOT/AppStream" "AppStream"

# Apache config: directory listing under /repo, no auth (lab subnet only).
cat > /etc/httpd/conf.d/repo.conf <<'EOF'
Alias /repo /var/www/html/repo
<Directory /var/www/html/repo>
    Options Indexes FollowSymLinks
    Require all granted
</Directory>
EOF

chown -R apache:apache "$WEBROOT"
restorecon -R "$WEBROOT" 2>/dev/null || true

firewall-cmd --permanent --zone=internal --add-service=http >/dev/null 2>&1 || true
firewall-cmd --reload >/dev/null
systemctl enable --now httpd

cat <<EOF

=== Offline mirror ready ===
  HTTP : http://<repo-server-ip>/repo/{BaseOS,AppStream}/
  NFS  : configured by setup-nfs.sh (same paths)
  Sizes: $(du -sh "$WEBROOT"/BaseOS "$WEBROOT"/AppStream 2>/dev/null | awk '{print $2": "$1}' | paste -sd ' / ' -)

The rest of the lab can now be brought up offline.
EOF
