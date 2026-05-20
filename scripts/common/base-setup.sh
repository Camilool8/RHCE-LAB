#!/bin/bash
# scripts/common/base-setup.sh [<subnet_cidr>]
# Base setup applied to every VM in the lab. Idempotent.
set -euo pipefail

SUBNET_CIDR="${1:-}"

echo "=== Base setup: $(hostname) ==="

# The AlmaLinux 9 cloud image is minimal — firewalld, NetworkManager (the
# defaults expected by RHCE practice), and a few CLI utilities aren't all
# present out of the box. Install them up front so later provisioners can
# rely on `systemctl enable --now firewalld` etc.
dnf install -y \
    vim wget curl net-tools bind-utils tar bash-completion \
    firewalld NetworkManager policycoreutils-python-utils \
  2>/dev/null \
  || echo "WARN: some base packages may already be installed"

# NetworkManager: required for configure-lab-network.sh and for everything the
# RHCE exam expects (nmcli is the canonical RHEL 9 tool).
systemctl enable --now NetworkManager

# firewalld: zones drive the lab's network policy. The lab subnet is bound to
# the `internal` zone (better fit than `public` for a closed lab; less
# permissive than `trusted`, so RHCE firewalld objectives still apply).
systemctl enable --now firewalld

if [ -n "$SUBNET_CIDR" ]; then
  firewall-cmd --permanent --zone=internal --add-source="$SUBNET_CIDR" \
    >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null
  echo "firewalld: lab subnet $SUBNET_CIDR bound to internal zone"
fi

echo "=== Base setup complete: $(hostname) ==="
