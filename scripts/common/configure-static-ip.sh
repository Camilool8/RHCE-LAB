#!/bin/bash
# scripts/common/configure-static-ip.sh <ip> <gateway> <cidr> <provider>
# Idempotent: sets a static IP on the lab interface ONLY when the lab is
# running under the `qemu` provider. Other providers configure the IP via
# Vagrant's private_network and this script becomes a no-op.
set -euo pipefail

IP="${1:?ip argument required}"
GW="${2:?gateway argument required}"
CIDR="${3:?cidr argument required}"
PROVIDER="${4:?provider argument required}"

if [ "$PROVIDER" != "qemu" ]; then
  echo "configure-static-ip: provider=$PROVIDER — skipping (handled by Vagrant)."
  exit 0
fi

NETMASK_BITS="${CIDR##*/}"

# Find the lab interface: prefer one already holding an IP in our subnet
# (socket_vmnet's DHCP may have leased one). Otherwise fall back to the
# non-default-route ethernet-style interface.
PFX=$(echo "$IP" | awk -F. '{print $1"."$2"."$3}')
LAB_IF=$(ip -o -4 addr show 2>/dev/null \
         | awk -v p="^${PFX}\\." '$4 ~ p {print $2; exit}')

if [ -z "$LAB_IF" ]; then
  DEFAULT_IF=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
  LAB_IF=$(ls /sys/class/net | grep -Ev "^(lo|virbr|docker|${DEFAULT_IF:-lo})$" | head -1)
fi

if [ -z "$LAB_IF" ]; then
  echo "ERROR: could not identify lab interface" >&2
  exit 1
fi

CURRENT=$(ip -o -4 addr show "$LAB_IF" 2>/dev/null | awk '{print $4}' | head -1 || true)
if [ "$CURRENT" = "${IP}/${NETMASK_BITS}" ]; then
  echo "configure-static-ip: $LAB_IF already at $IP — no change."
  exit 0
fi

CON=$(nmcli -t -f NAME,DEVICE c show --active 2>/dev/null \
      | awk -F: -v d="$LAB_IF" '$2==d{print $1; exit}')
if [ -z "$CON" ]; then
  CON="lab-${LAB_IF}"
  nmcli con add type ethernet ifname "$LAB_IF" con-name "$CON" >/dev/null
fi

echo "configure-static-ip: setting $LAB_IF -> ${IP}/${NETMASK_BITS} (gw=$GW)"
nmcli con mod "$CON" \
  ipv4.method manual \
  ipv4.addresses "${IP}/${NETMASK_BITS}" \
  ipv4.gateway "$GW" \
  ipv4.dns "$GW" >/dev/null
nmcli con up "$CON" >/dev/null
