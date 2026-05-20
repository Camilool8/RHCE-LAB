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
