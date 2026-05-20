#!/bin/bash
# Usage: create-users.sh
set -euo pipefail

echo "=== Creating lab users on $(hostname) ==="

create_user_with_passwordless_sudo() {
  local user="$1" pass="$2"
  if ! id "$user" &>/dev/null; then
    useradd -m -s /bin/bash "$user"
  fi
  echo "${user}:${pass}" | chpasswd
  echo "${user} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${user}"
  chmod 0440 "/etc/sudoers.d/${user}"
}

create_user_with_passwordless_sudo student 1234
create_user_with_passwordless_sudo redhat redhat

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
if [ -d /etc/ssh/sshd_config.d ]; then
  echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/01-lab.conf
fi
systemctl restart sshd

echo "=== Lab users created on $(hostname) ==="
