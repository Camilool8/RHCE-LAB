#!/bin/bash
# Usage: setup-control.sh <ip> <hostname> [<ip> <hostname> ...]
set -euo pipefail

echo "=== Control node setup ==="

dnf install -y \
    ansible-core python3 python3-pip podman git tar createrepo_c \
    python3.11 python3.11-pip python3.11-devel \
    gcc make libffi-devel openssl-devel krb5-devel \
    redhat-rpm-config

dnf install -y epel-release 2>/dev/null || true
if command -v crb >/dev/null 2>&1; then
  crb enable 2>/dev/null || true
else
  dnf config-manager --set-enabled crb 2>/dev/null || true
fi
dnf install -y oniguruma-devel 2>/dev/null \
  || echo "INFO: oniguruma-devel not available; pip onigurumacffi build may fail"

install -d -m 700 -o student -g student /home/student/.ssh
install -m 600 -o student -g student /tmp/RH294-LAB     /home/student/.ssh/RH294-LAB
install -m 644 -o student -g student /tmp/RH294-LAB.pub /home/student/.ssh/RH294-LAB.pub
restorecon -R /home/student/.ssh 2>/dev/null || true

install -d -m 755 -o student -g student /home/student/ansible
install -m 644 -o student -g student /tmp/vimrc /home/student/.vimrc

sed -i '/# RHCE-LAB BEGIN/,/# RHCE-LAB END/d' /etc/hosts
{
  echo "# RHCE-LAB BEGIN"
  while [ "$#" -ge 2 ]; do
    ip="$1"; host="$2"; shift 2
    echo "${ip} ${host} ${host}.example.com ansible-${host}"
  done
  echo "# RHCE-LAB END"
} >> /etc/hosts

install_navigator_via_rhel_subscription() {
  command -v subscription-manager >/dev/null 2>&1 || return 1
  subscription-manager status >/dev/null 2>&1 || return 1
  local arch repo
  arch=$(uname -m)
  repo="ansible-automation-platform-2.5-for-rhel-9-${arch}-rpms"
  echo "Detected RHEL with active subscription — enabling ${repo}"
  subscription-manager repos --enable="$repo" >/dev/null 2>&1 || return 1
  dnf install -y ansible-navigator 2>/dev/null
}

install_navigator_via_dnf_epel() {
  dnf list --available ansible-navigator >/dev/null 2>&1 || return 1
  echo "Installing ansible-navigator from EPEL"
  dnf install -y ansible-navigator 2>&1 | tail -5
}

install_navigator_via_pip() {
  echo "Installing ansible-navigator via python3.11 -m pip --user (student)"
  runuser -l student -c '
    set -o pipefail
    python3.11 -m pip install --user --upgrade pip wheel 2>&1 | tail -3
    if ! python3.11 -m pip install --user ansible-dev-tools 2>&1 | tail -8; then
      python3.11 -m pip install --user ansible-navigator 2>&1 | tail -8
    fi
  '
}

has_navigator() {
  command -v ansible-navigator >/dev/null 2>&1 \
    || runuser -l student -c 'command -v ansible-navigator' >/dev/null 2>&1
}

if ! has_navigator; then
  if ! install_navigator_via_rhel_subscription \
     && ! install_navigator_via_dnf_epel; then
    install_navigator_via_pip \
      || echo "WARN: ansible-navigator install failed — use --execution-environment false"
  fi
fi

EE_IMAGE="ghcr.io/ansible/community-ansible-dev-tools:latest"

cat > /home/student/.ansible-navigator.yml <<EOF
---
ansible-navigator:
  execution-environment:
    enabled: true
    image: ${EE_IMAGE}
    pull:
      policy: missing
    container-engine: podman
EOF
chown student:student /home/student/.ansible-navigator.yml

runuser -l student -c "podman pull '$EE_IMAGE'" 2>&1 | tail -3 \
  || echo "WARN: EE image pull failed — ansible-navigator --execution-environment false will still work"

echo "=== Control node setup complete ==="
