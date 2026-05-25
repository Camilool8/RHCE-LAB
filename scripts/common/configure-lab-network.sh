#!/bin/bash
# Usage: configure-lab-network.sh <lab_ip> <subnet_cidr>
set -euo pipefail

LAB_IP="${1:?lab IP argument required (e.g. 192.168.56.40)}"
CIDR="${2:?subnet CIDR argument required (e.g. 192.168.56.0/24)}"
NETMASK_BITS="${CIDR##*/}"

if ! systemctl is-active --quiet NetworkManager; then
  echo "ERROR: NetworkManager is not active." >&2
  exit 1
fi

find_lab_interface() {
  local default_if name
  default_if=$(ip -4 route show default 2>/dev/null | awk '/^default/{print $5; exit}')
  for iface in /sys/class/net/*; do
    name=$(basename "$iface")
    case "$name" in
      lo|virbr*|docker*|cni*|veth*|"${default_if:-_skip_}") continue ;;
    esac
    echo "$name"
    return 0
  done
  return 1
}

LAB_IF=$(find_lab_interface) || {
  echo "WARN: no lab interface found. Skipping."
  exit 0
}

echo "Configuring $LAB_IF -> ${LAB_IP}/${NETMASK_BITS} (zone=internal)"

while read -r conn_name; do
  [ "$conn_name" = "lab" ] && continue
  nmcli connection delete "$conn_name" >/dev/null 2>&1 || true
done < <(
  nmcli -t -f NAME,DEVICE connection show 2>/dev/null \
    | awk -F: -v d="$LAB_IF" '$2==d {print $1}'
)

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

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --zone=internal --add-source="${CIDR}" >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null
fi

echo "Lab network ready on $LAB_IF: $(ip -4 -o addr show "$LAB_IF" | awk '{print $4}' | tr '\n' ' ')"
