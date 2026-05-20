#!/bin/bash
# scripts/host/setup-socket-vmnet.sh
# One-time macOS Apple Silicon setup for RHCE-LAB scenario C (qemu provider).
# Installs socket_vmnet via Homebrew and runs it as a launchd daemon configured
# for the lab subnet defined in config.yaml. Re-running is idempotent.
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: this script is macOS-only." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew is required (https://brew.sh)" >&2
  exit 1
fi

if ! brew list socket_vmnet >/dev/null 2>&1; then
  echo "Installing socket_vmnet via Homebrew..."
  brew install socket_vmnet
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SUBNET=$(awk '/^network:/{f=1;next} f && /subnet:/{gsub(/[" ]/,"",$2); print $2; exit}' "$ROOT/config.yaml")
if [ -z "$SUBNET" ]; then
  echo "ERROR: could not read network.subnet from $ROOT/config.yaml" >&2
  exit 1
fi
GATEWAY="${SUBNET}.1"

BREW_PREFIX="$(brew --prefix)"
SOCKET_VMNET_BIN="$BREW_PREFIX/opt/socket_vmnet/bin/socket_vmnet"
PLIST="/Library/LaunchDaemons/com.lima-vm.socket_vmnet.plist"

echo "Writing $PLIST (gateway=${GATEWAY}, socket=/var/run/socket_vmnet)..."
sudo tee "$PLIST" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.lima-vm.socket_vmnet</string>
    <key>Program</key>
    <string>${SOCKET_VMNET_BIN}</string>
    <key>ProgramArguments</key>
    <array>
      <string>${SOCKET_VMNET_BIN}</string>
      <string>--vmnet-mode=shared</string>
      <string>--vmnet-gateway=${GATEWAY}</string>
      <string>/var/run/socket_vmnet</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/var/log/socket_vmnet.err.log</string>
    <key>StandardOutPath</key>
    <string>/var/log/socket_vmnet.out.log</string>
  </dict>
</plist>
EOF
sudo chown root:wheel "$PLIST"
sudo chmod 644 "$PLIST"

echo "Reloading daemon..."
sudo launchctl unload "$PLIST" >/dev/null 2>&1 || true
sudo launchctl load   "$PLIST"

# Give the daemon a moment to create the socket
for i in 1 2 3 4 5; do
  [ -S /var/run/socket_vmnet ] && break
  sleep 1
done

if [ -S /var/run/socket_vmnet ]; then
  echo "socket_vmnet is running. Socket: /var/run/socket_vmnet  Gateway: ${GATEWAY}"
else
  echo "ERROR: socket_vmnet failed to start. See /var/log/socket_vmnet.err.log" >&2
  exit 1
fi
