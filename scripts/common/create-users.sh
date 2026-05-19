#!/bin/bash
# Creates the lab user accounts on every VM:
#   x69van / 1234   (mandatory — all RHCE task paths use /home/x69van)
#   redhat / redhat (convenience admin account)
set -euo pipefail

echo "=== Creating lab users on $(hostname) ==="

create_user() {
  local user="$1" pass="$2"
  if ! id "$user" &>/dev/null; then
    useradd -m -s /bin/bash "$user"
  fi
  echo "${user}:${pass}" | chpasswd
  echo "${user} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${user}"
  chmod 0440 "/etc/sudoers.d/${user}"
}

create_user x69van 1234
create_user redhat redhat

# Enable password SSH (lab convenience).
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config
if [ -d /etc/ssh/sshd_config.d ]; then
  echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/01-lab.conf
fi
systemctl restart sshd

echo "=== Lab users created on $(hostname) ==="
