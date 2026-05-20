#!/bin/bash
# scripts/common/configure-lab-network.sh <lab_ip> <subnet_cidr>
#
# Assigns the lab IP to the second network interface via NetworkManager and
# puts the connection in firewalld's `internal` zone. Runs FIRST in the
# provisioner chain on every VM and across every Vagrant provider — Vagrant's
# RedHat guest capability writes obsolete /etc/sysconfig/network-scripts files
# that AlmaLinux 9.6+ does not read (HashiCorp Vagrant issue #13744), so the
# Vagrantfile declares `private_network` with `auto_config: false` and lets
# this script do the in-guest configuration uniformly.
#
# Idempotent. Safe to re-run.
set -euo pipefail

LAB_IP="${1:?lab IP argument required (e.g. 192.168.56.40)}"
CIDR="${2:?subnet CIDR argument required (e.g. 192.168.56.0/24)}"
NETMASK_BITS="${CIDR##*/}"

# Make sure NetworkManager is the active network stack.
if ! systemctl is-active --quiet NetworkManager; then
  echo "ERROR: NetworkManager is not active." >&2
  exit 1
fi

# Identify the lab interface: any non-loopback / non-bridge interface that is
# NOT the default route's interface. The default-route interface is Vagrant's
# NAT used for ssh; everything else (the second NIC attached by private_network)
# is what we configure.
DEFAULT_IF=$(ip -4 route show default 2>/dev/null | awk '/^default/{print $5; exit}')
LAB_IF=""
for iface in /sys/class/net/*; do
  name=$(basename "$iface")
  case "$name" in
    lo|virbr*|docker*|cni*|veth*|"${DEFAULT_IF:-_skip_}") continue ;;
  esac
  LAB_IF="$name"
  break
done

if [ -z "$LAB_IF" ]; then
  echo "WARN: no lab interface found (default=${DEFAULT_IF:-none}). Skipping."
  exit 0
fi

echo "Configuring $LAB_IF -> ${LAB_IP}/${NETMASK_BITS} (zone=internal)"

# Delete any pre-existing NM connection that grabbed this interface
# (e.g. "Wired connection 2" auto-created on link-up) so we own it cleanly.
while read -r conn_name; do
  [ "$conn_name" = "lab" ] && continue
  nmcli connection delete "$conn_name" >/dev/null 2>&1 || true
done < <(
  nmcli -t -f NAME,DEVICE connection show 2>/dev/null \
    | awk -F: -v d="$LAB_IF" '$2==d {print $1}'
)

# Create the lab connection if it does not already exist.
if ! nmcli -t -f NAME connection show 2>/dev/null | grep -qx 'lab'; then
  nmcli connection add type ethernet \
    con-name lab \
    ifname "$LAB_IF" \
    ipv4.method manual \
    ipv4.addresses "${LAB_IP}/${NETMASK_BITS}" \
    ipv6.method disabled \
    connection.autoconnect yes \
    connection.zone internal \
    >/dev/null
fi

# Reapply target settings every run (the create above is a no-op on re-run,
# but if a previous run left wrong values, modify will correct them).
nmcli connection modify lab \
  connection.interface-name "$LAB_IF" \
  ipv4.method manual \
  ipv4.addresses "${LAB_IP}/${NETMASK_BITS}" \
  ipv4.gateway "" \
  ipv4.dns "" \
  ipv6.method disabled \
  connection.autoconnect yes \
  connection.zone internal \
  >/dev/null

nmcli connection up lab >/dev/null 2>&1 || true

# Belt-and-braces: also bind the lab subnet to firewalld's internal zone by
# source address. This makes the policy correct even if NM-firewalld zone
# integration fails to assign the interface.
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --zone=internal --add-source="${CIDR}" >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null
fi

echo "Lab network ready on $LAB_IF: $(ip -4 -o addr show "$LAB_IF" | awk '{print $4}' | tr '\n' ' ')"
