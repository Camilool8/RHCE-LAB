#!/bin/bash
# Usage: base-setup.sh [<subnet_cidr>]
set -euo pipefail

SUBNET_CIDR="${1:-}"

echo "=== Base setup: $(hostname) ==="

dnf install -y \
    vim wget curl net-tools bind-utils tar bash-completion \
    firewalld NetworkManager policycoreutils-python-utils \
  || echo "WARN: dnf install reported a non-zero exit (packages may already be present)"

systemctl enable --now NetworkManager
systemctl enable --now firewalld

if [ -n "$SUBNET_CIDR" ]; then
  firewall-cmd --permanent --zone=internal --add-source="$SUBNET_CIDR" \
    >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null
  echo "firewalld: lab subnet $SUBNET_CIDR bound to internal zone"
fi

echo "=== Base setup complete: $(hostname) ==="
