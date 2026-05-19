#!/bin/bash
# Base setup applied to every VM in the lab.
set -euo pipefail

echo "=== Base setup: $(hostname) ==="

dnf install -y vim wget curl net-tools bind-utils tar bash-completion \
  2>/dev/null || echo "WARN: some base packages may already be installed"

systemctl enable --now firewalld

echo "=== Base setup complete: $(hostname) ==="
