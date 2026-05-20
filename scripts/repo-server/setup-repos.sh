#!/bin/bash
# Usage: setup-repos.sh
set -euo pipefail

echo "=== Repo server: HTTP repositories ==="

WEBROOT=/var/www/html/repo
mkdir -p "$WEBROOT/BaseOS" "$WEBROOT/AppStream"

dnf install -y httpd createrepo_c

iso_device() {
  for dev in /dev/sr0 /dev/sr1 /dev/cdrom; do
    [ -b "$dev" ] && { echo "$dev"; return 0; }
  done
  return 1
}

iso_copied=false
if iso=$(iso_device); then
  mkdir -p /mnt/iso
  if mount -o ro "$iso" /mnt/iso 2>/dev/null \
     && [ -d /mnt/iso/BaseOS ] && [ -d /mnt/iso/AppStream ]; then
    echo "ISO detected at $iso — copying BaseOS/AppStream (this can take several minutes)"
    cp -a /mnt/iso/BaseOS/. "$WEBROOT/BaseOS/"
    cp -a /mnt/iso/AppStream/. "$WEBROOT/AppStream/"
    iso_copied=true
    umount /mnt/iso
  fi
fi

if ! $iso_copied; then
  echo "No ISO — creating empty repo structure."
  echo "Managed nodes will use the distribution's internet repos for package installs."
fi

[ -d "$WEBROOT/BaseOS/repodata" ]    || createrepo_c "$WEBROOT/BaseOS"
[ -d "$WEBROOT/AppStream/repodata" ] || createrepo_c "$WEBROOT/AppStream"

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

echo "=== HTTP repos ready at http://<repo-ip>/repo/ ==="
