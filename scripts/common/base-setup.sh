#!/bin/bash
# Base setup applied to every VM in the lab.
set -euo pipefail

echo "=== Base setup: $(hostname) ==="

# firewalld is not present on the AlmaLinux 9 cloud image — install it
# explicitly so later provisioning (httpd, NFS) can open service ports.
dnf install -y vim wget curl net-tools bind-utils tar bash-completion firewalld \
  2>/dev/null || echo "WARN: some base packages may already be installed"

systemctl enable --now firewalld

echo "=== Base setup complete: $(hostname) ==="
