#!/bin/bash
# scripts/control/setup-control.sh <ip> <hostname> [<ip> <hostname> ...]
#
# Control-node provisioning:
# 1. Install ansible-core + supporting packages.
# 2. Install ansible-navigator robustly:
#    - On RHEL with an Ansible Automation Platform subscription, enable the
#      AAP repo and `dnf install ansible-navigator` — the same path students
#      will see in a real exam environment.
#    - Otherwise (AlmaLinux / Rocky / unsubscribed RHEL) fall back to
#      `python3.11 -m pip install --user ansible-dev-tools` as the student
#      user, which pulls in ansible-navigator + ansible-creator + lint etc.
# 3. Drop a sane ~/.ansible-navigator.yml referencing the multi-arch community
#    execution environment image (ghcr.io/ansible/community-ansible-dev-tools;
#    quay.io/ansible/creator-ee was archived August 2024).
# 4. Pre-pull the EE image so task 18 (ansible-navigator) works offline.
#
# Args: repeated "<ip> <hostname>" pairs for every lab host (used to populate
# /etc/hosts on the control node).
set -euo pipefail

echo "=== Control node setup ==="

# --- Core packages ---
# python3.11: ansible-dev-tools requires Python >= 3.10; AlmaLinux 9 ships
#             python3.9 as the platform Python.
# gcc + python3.11-devel + libffi-devel + openssl-devel + krb5-devel:
#             build deps for cffi / cryptography when pip has no prebuilt
#             wheel for the host architecture.
# oniguruma-devel (from EPEL): C header dependency of `onigurumacffi`, which
#             ansible-navigator's TUI pulls in transitively. Without it,
#             pip's source-build of onigurumacffi fails and the whole
#             ansible-dev-tools install aborts.
dnf install -y epel-release 2>/dev/null \
  || echo "WARN: EPEL install failed (may already be present)"

dnf install -y \
    ansible-core python3 python3-pip podman git tar createrepo_c \
    python3.11 python3.11-pip python3.11-devel \
    gcc make libffi-devel openssl-devel krb5-devel oniguruma-devel \
    redhat-rpm-config \
  2>/dev/null \
  || echo "WARN: some control packages may already be installed"

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

# -----------------------------------------------------------------------------
# ansible-navigator install
# -----------------------------------------------------------------------------
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

install_navigator_via_pip() {
  echo "Installing ansible-navigator via python3.11 -m pip --user (student)"
  # `runuser -l` runs a full login session (cwd=$HOME, no env from caller).
  # Use a heredoc-style `-c` argument so the inner shell has all of pip's
  # output visible, then tail to keep the Vagrant log readable.
  runuser -l student -c '
    set -o pipefail
    python3.11 -m pip install --user --upgrade pip wheel 2>&1 | tail -3
    # ansible-dev-tools bundles ansible-navigator + ansible-creator +
    # ansible-lint + molecule + ansible-builder. If the meta-package fails
    # (rare — needs all build deps), fall back to plain ansible-navigator.
    if ! python3.11 -m pip install --user ansible-dev-tools 2>&1 | tail -8; then
      python3.11 -m pip install --user ansible-navigator 2>&1 | tail -8
    fi
  '
}

# Probe ansible-navigator from BOTH root and student PATHs (RHEL-subscription
# install lands in /usr/bin; pip --user lands in /home/student/.local/bin).
has_navigator() {
  command -v ansible-navigator >/dev/null 2>&1 \
    || runuser -l student -c 'command -v ansible-navigator' >/dev/null 2>&1
}

if ! has_navigator; then
  if ! install_navigator_via_rhel_subscription; then
    install_navigator_via_pip \
      || echo "WARN: ansible-navigator install failed — use --execution-environment false"
  fi
fi

# -----------------------------------------------------------------------------
# ansible-navigator settings + EE image
# -----------------------------------------------------------------------------
# community-ansible-dev-tools is the maintained multi-arch (amd64+arm64) EE.
# creator-ee was archived in August 2024.
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

# Pre-pull the EE so the first navigator run works without internet.
# `runuser -l student` opens a login session (cwd=/home/student); plain
# `sudo -u student` inherits the caller's cwd which here is /home/vagrant
# (unreadable by `student`) and causes podman to fail with "cannot chdir to
# /home/vagrant: Permission denied".
runuser -l student -c "podman pull '$EE_IMAGE'" 2>&1 | tail -3 \
  || echo "WARN: EE image pull failed — ansible-navigator --execution-environment false will still work"

echo "=== Control node setup complete ==="
