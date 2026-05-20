#!/bin/bash
# Control node setup: install Ansible tooling, install the RH294-LAB private
# key for student, populate /etc/hosts, and pre-pull an execution environment.
# Args: repeated "<ip> <hostname>" pairs for every lab host.
set -euo pipefail

echo "=== Control node setup ==="

# --- Ansible tooling ---
dnf install -y ansible-core python3 python3-pip podman git tar 2>/dev/null \
  || echo "WARN: some control packages may already be installed"
dnf install -y ansible-navigator 2>/dev/null || true
if ! command -v ansible-navigator &>/dev/null; then
  pip3 install ansible-navigator 2>/dev/null \
    || echo "WARN: ansible-navigator not installed (task 18 may need manual setup)"
fi

# --- RH294-LAB SSH key for student (uploaded to /tmp by Vagrant) ---
install -d -m 700 -o student -g student /home/student/.ssh
install -m 600 -o student -g student /tmp/RH294-LAB     /home/student/.ssh/RH294-LAB
install -m 644 -o student -g student /tmp/RH294-LAB.pub /home/student/.ssh/RH294-LAB.pub
restorecon -R /home/student/.ssh 2>/dev/null || true

# --- Working directory and vimrc helper ---
install -d -m 755 -o student -g student /home/student/ansible
install -m 644 -o student -g student /tmp/vimrc /home/student/.vimrc

# --- /etc/hosts: args are repeated "<ip> <hostname>" pairs ---
sed -i '/# RHCE-LAB BEGIN/,/# RHCE-LAB END/d' /etc/hosts
{
  echo "# RHCE-LAB BEGIN"
  while [ "$#" -ge 2 ]; do
    ip="$1"; host="$2"; shift 2
    echo "${ip} ${host} ${host}.example.com ansible-${host}"
  done
  echo "# RHCE-LAB END"
} >> /etc/hosts

# --- Pre-pull an execution environment for ansible-navigator (task 18) ---
sudo -u student podman pull quay.io/ansible/creator-ee:latest 2>/dev/null \
  || echo "WARN: EE image pull failed — run ansible-navigator with '--execution-environment false'"

echo "=== Control node setup complete ==="
