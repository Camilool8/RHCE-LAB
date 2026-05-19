#!/bin/bash
# Repo server: build BaseOS/AppStream HTTP repositories.
# If a DVD ISO is attached (/dev/sr0) its content is copied; otherwise
# empty-but-valid repo structures are created.
set -euo pipefail

echo "=== Repo server: HTTP repositories ==="

WEBROOT=/var/www/html/repo
mkdir -p "$WEBROOT/BaseOS" "$WEBROOT/AppStream"

dnf install -y httpd createrepo_c

ISO_FOUND=false
if [ -b /dev/sr0 ]; then
  mkdir -p /mnt/iso
  if mount -o ro /dev/sr0 /mnt/iso 2>/dev/null \
     && [ -d /mnt/iso/BaseOS ] && [ -d /mnt/iso/AppStream ]; then
    echo "ISO detected — copying BaseOS/AppStream (this can take several minutes)"
    cp -a /mnt/iso/BaseOS/. "$WEBROOT/BaseOS/"
    cp -a /mnt/iso/AppStream/. "$WEBROOT/AppStream/"
    ISO_FOUND=true
    umount /mnt/iso
  fi
fi

if [ "$ISO_FOUND" = false ]; then
  echo "No ISO — creating empty repo structure."
  echo "Managed nodes will use AlmaLinux internet repos for package installs."
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

firewall-cmd --permanent --add-service=http
firewall-cmd --reload
systemctl enable --now httpd

echo "=== HTTP repos ready at http://<repo-ip>/repo/ ==="
