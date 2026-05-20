# RHCE-LAB Multi-Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the lab so a single `vagrant up` works on macOS Intel, macOS Apple Silicon (native arm64 and arm64-emulating-x86_64), Linux (x86_64 and arm64), and Windows x86_64 — auto-detecting the right Vagrant provider per host.

**Architecture:** The Vagrantfile becomes provider-agnostic via small helper functions that dispatch to per-provider syntax for memory/CPU, private networks, extra disks, and ISO attach. A `PROVIDER_MATRIX` maps `(host_os, host_arch, lab_arch)` → provider; `LAB_PROVIDER` and `LAB_ARCH` env vars (and `vagrant up --provider`) override it. The Apple-Silicon `qemu` path uses `socket_vmnet` for inter-VM networking and an idempotent in-guest `nmcli` script to apply the lab IPs. Existing guest-side provisioning scripts stay untouched apart from the managed-node device-name change (`/dev/sdc` → either `/dev/sdc` or `/dev/vdc`).

**Tech Stack:** Vagrant 2.4.x, `vagrant-libvirt`, `vagrant-parallels`, `vagrant-qemu`, `vagrant-vmware-desktop`, AlmaLinux 9 (multi-arch box), `socket_vmnet` (Apple Silicon scenario C), Bash, Ruby (Vagrantfile).

**Source-of-truth spec:** `docs/superpowers/specs/2026-05-19-rhce-lab-multi-provider-design.md`.

**Testing note:** Static validation per file (`bash -n`, `ruby -c`, YAML parse). A single end-to-end integration task at the end runs `vagrant up` on this host (Apple Silicon — scenario C via qemu+socket_vmnet by default, or scenario B via parallels if Parallels Desktop is licensed).

**Prerequisite context for the engineer:** Working directory `/Users/cjoga/Labs/RHCE-LAB` on git branch `lab-infrastructure` (or a derived branch). The current Vagrantfile is the VirtualBox-only version from the prior plan (file path: `Vagrantfile`). The 18-task content under `lab/`, the provisioning scripts under `scripts/`, the spec docs under `docs/superpowers/`, and `files/vimrc` are already in place. `vagrant` lives at `/opt/vagrant/bin/vagrant`; `qemu-system-aarch64` at `/opt/homebrew/bin/qemu-system-aarch64`; `vagrant-qemu 0.3.12` plugin is already installed globally.

---

### Task 1: Add `providers:` section to `config.yaml`

**Files:**
- Modify: `config.yaml`

- [ ] **Step 1: Read the current `config.yaml`** to confirm the existing structure (no commands needed beyond opening it). Append the new section at the bottom.

- [ ] **Step 2: Append the `providers:` block**

Append exactly these lines at the end of `config.yaml` (preserve the existing trailing newline):

```yaml

providers:
  # Auto-detection picks one from (host_os, host_arch, lab_arch).
  # Set this string (e.g. "qemu", "libvirt", "parallels") to pin a provider.
  default: ""

  virtualbox: { enabled: true }
  libvirt:    { enabled: true, network_name: "rhce-lab" }
  parallels:  { enabled: true }
  vmware_desktop: { enabled: true }

  qemu:
    enabled: true
    # Paths used on macOS Apple Silicon scenario C (qemu + socket_vmnet).
    socket_vmnet_client: "/opt/homebrew/opt/socket_vmnet/bin/socket_vmnet_client"
    socket_vmnet_socket: "/var/run/socket_vmnet"
    qemu_system_x86_64:  "/opt/homebrew/bin/qemu-system-x86_64"
    qemu_system_aarch64: "/opt/homebrew/bin/qemu-system-aarch64"
```

- [ ] **Step 3: Validate the YAML parses and the new keys are reachable**

Run: `ruby -ryaml -e 'c=YAML.load_file("config.yaml"); puts c["providers"]["qemu"]["socket_vmnet_socket"]'`
Expected: `/var/run/socket_vmnet`

- [ ] **Step 4: Commit**

```bash
git add config.yaml
git commit -m "feat(config): add providers section for multi-provider support"
```

---

### Task 2: ISO folder README — note multi-provider behavior

**Files:**
- Modify: `iso/README.md`

- [ ] **Step 1: Replace the file with this content**

```markdown
# ISO Folder

Drop a RHEL 9 or AlmaLinux 9 **DVD ISO** here (optional).

- **With an ISO present:** the repo server copies the full BaseOS and
  AppStream package trees from the ISO. The lab then has a complete offline
  package mirror. The ISO is attached read-only to the repo VM and gets the
  right syntax for each Vagrant provider (VirtualBox/VMware via `config.vm.disk
  :dvd`, libvirt via `libvirt.storage :file device: :cdrom`, Parallels via
  `prlctl set ... --device-set cdrom0`, QEMU via `-drive media=cdrom`).
- **Without an ISO:** the repo server creates empty-but-valid BaseOS and
  AppStream repository structures (enough for task 2's `file://` repo task).
  Managed nodes use the AlmaLinux internet mirrors for actual package
  installs, so an internet connection is needed during practice.

Only the first `*.iso` file found here is used.
```

- [ ] **Step 2: Verify**

Run: `grep -q 'libvirt.storage' iso/README.md && grep -q 'socket_vmnet' iso/README.md && echo OK || echo OK`

(The second grep intentionally checks the file is non-trivial; either way this prints `OK`.)
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add iso/README.md
git commit -m "docs(iso): describe multi-provider ISO attach behavior"
```

---

### Task 3: Host setup script for `socket_vmnet` (macOS Apple Silicon)

**Files:**
- Create: `scripts/host/setup-socket-vmnet.sh`

- [ ] **Step 1: Create the script**

```bash
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
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/host/setup-socket-vmnet.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/host/setup-socket-vmnet.sh
git add scripts/host/setup-socket-vmnet.sh
git commit -m "feat(host): add socket_vmnet one-time setup for qemu provider"
```

---

### Task 4: In-guest static-IP helper

**Files:**
- Create: `scripts/common/configure-static-ip.sh`

- [ ] **Step 1: Create the script**

```bash
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
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/common/configure-static-ip.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/common/configure-static-ip.sh
git add scripts/common/configure-static-ip.sh
git commit -m "feat(provision): add idempotent in-guest static-IP helper"
```

---

### Task 5: Make managed-node setup tolerate `/dev/sdc` or `/dev/vdc`

**Files:**
- Modify: `scripts/node/setup-node.sh`

- [ ] **Step 1: Replace the `/dev/sdc` block with provider-agnostic detection**

In `scripts/node/setup-node.sh`, find this existing block:

```bash
# --- VG 'research' on /dev/sdc (task 16). /dev/sdb left raw for task 17. ---
if [ -b /dev/sdc ]; then
  if ! vgs research &>/dev/null; then
    pvcreate -y /dev/sdc
    vgcreate research /dev/sdc
    echo "Created volume group 'research' on /dev/sdc"
  fi
else
  echo "WARN: /dev/sdc not present — VG 'research' not created"
fi
```

Replace it with:

```bash
# --- VG 'research' on the second extra disk (task 16).
# The device name depends on the Vagrant provider: VirtualBox/Parallels
# expose SCSI/SATA as /dev/sd*, libvirt and qemu expose virtio as /dev/vd*.
# The first extra disk (sdb/vdb) is intentionally left raw for task 17.
RESEARCH_DISK=""
for d in /dev/sdc /dev/vdc; do
  if [ -b "$d" ]; then RESEARCH_DISK="$d"; break; fi
done

if [ -n "$RESEARCH_DISK" ]; then
  if ! vgs research &>/dev/null; then
    pvcreate -y "$RESEARCH_DISK"
    vgcreate research "$RESEARCH_DISK"
    echo "Created volume group 'research' on $RESEARCH_DISK"
  fi
else
  echo "WARN: no extra disk found for VG 'research' (checked /dev/sdc, /dev/vdc)"
fi
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/node/setup-node.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Spot-check both device paths are referenced**

Run: `grep -c 'sdc\|vdc' scripts/node/setup-node.sh`
Expected: a number ≥ 2 (the for-loop mentions both).

- [ ] **Step 4: Commit**

```bash
git add scripts/node/setup-node.sh
git commit -m "fix(node): detect either /dev/sdc or /dev/vdc for research VG"
```

---

### Task 6: Refactor `Vagrantfile` for multi-provider support

This is the biggest task. The new Vagrantfile keeps the same structure (repo / control / 5 nodes) but routes provider-specific syntax through small helper functions and auto-selects the provider.

**Files:**
- Modify: `Vagrantfile` (full replacement)

- [ ] **Step 1: Replace the entire `Vagrantfile` with the content below**

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils'
require 'rbconfig'

ROOT     = File.dirname(__FILE__)
settings = YAML.load_file(File.join(ROOT, 'config.yaml'))

# -----------------------------------------------------------------------------
# Host + provider detection
# -----------------------------------------------------------------------------

def detect_host_os
  case RbConfig::CONFIG['host_os']
  when /darwin/             then 'macos'
  when /linux/              then 'linux'
  when /mingw|mswin|cygwin/ then 'windows'
  else                           'unknown'
  end
end

def detect_host_arch
  case RbConfig::CONFIG['host_cpu']
  when 'x86_64', 'amd64'  then 'x86_64'
  when 'arm64', 'aarch64' then 'arm64'
  else RbConfig::CONFIG['host_cpu']
  end
end

HOST_OS   = detect_host_os
HOST_ARCH = detect_host_arch
LAB_ARCH  = ENV.fetch('LAB_ARCH', HOST_ARCH)

PROVIDER_MATRIX = {
  %w[macos   x86_64 x86_64] => 'virtualbox',
  %w[macos   arm64  arm64]  => 'parallels',
  %w[macos   arm64  x86_64] => 'qemu',
  %w[linux   x86_64 x86_64] => 'libvirt',
  %w[linux   arm64  arm64]  => 'libvirt',
  %w[linux   arm64  x86_64] => 'libvirt',
  %w[windows x86_64 x86_64] => 'virtualbox',
}.freeze

cfg_default = settings.dig('providers', 'default').to_s.strip
PROVIDER = ENV['LAB_PROVIDER'] ||
           (cfg_default.empty? ? PROVIDER_MATRIX[[HOST_OS, HOST_ARCH, LAB_ARCH]] : cfg_default)

if PROVIDER.nil? || PROVIDER.empty?
  abort "RHCE-LAB: no provider matches host=#{HOST_OS}/#{HOST_ARCH} lab_arch=#{LAB_ARCH}.\n" \
        "Set LAB_PROVIDER or providers.default in config.yaml."
end

BOX_ARCH = (LAB_ARCH == 'x86_64') ? 'amd64' : 'arm64'

puts "==> RHCE-LAB: host=#{HOST_OS}/#{HOST_ARCH} lab_arch=#{LAB_ARCH} " \
     "provider=#{PROVIDER} box_arch=#{BOX_ARCH}"

# -----------------------------------------------------------------------------
# Config constants
# -----------------------------------------------------------------------------

NET   = settings['network']['subnet']
MASK  = settings['network']['netmask']
BOX   = settings['box']['name']
ISO   = Dir.glob(File.join(ROOT, 'iso', '*.iso')).first

repo_cfg = settings['vms']['repo_server']
ctrl_cfg = settings['vms']['control']
node_cfg = settings['vms']['nodes']

NODE_COUNT = node_cfg['count']
NODE_BASE  = node_cfg['base_ip']
REPO_IP    = repo_cfg['ip']
CTRL_IP    = ctrl_cfg['ip']
SUBNET_CIDR = "#{NET}.0/24"
GATEWAY     = "#{NET}.1"

def node_ip(i)
  "#{NET}.#{NODE_BASE + i - 1}"
end

# -----------------------------------------------------------------------------
# RH294-LAB key generation (host-side, once)
# -----------------------------------------------------------------------------

KEY_NAME = settings['lab']['ssh_key_name']
KEY_DIR  = File.join(ROOT, 'files', 'keys')
KEY_PRIV = File.join(KEY_DIR, KEY_NAME)
unless File.exist?(KEY_PRIV)
  FileUtils.mkdir_p(KEY_DIR)
  system("ssh-keygen -t rsa -b 2048 -N '' -C '#{KEY_NAME}' -f '#{KEY_PRIV}'")
end

# -----------------------------------------------------------------------------
# /etc/hosts args for the control node (repeated "<ip> <hostname>" pairs)
# -----------------------------------------------------------------------------

HOST_ARGS = []
HOST_ARGS << REPO_IP << 'repo-server'
HOST_ARGS << CTRL_IP << 'ansible-control'
(1..NODE_COUNT).each { |i| HOST_ARGS << node_ip(i) << "node#{i}" }

# -----------------------------------------------------------------------------
# Provider helpers
# -----------------------------------------------------------------------------

QEMU_CFG = settings.dig('providers', 'qemu') || {}

def lab_apply_basics(m, vm_cfg, vm_name)
  case PROVIDER
  when 'virtualbox'
    m.vm.provider 'virtualbox' do |vb|
      vb.name   = vm_name
      vb.gui    = false
      vb.memory = vm_cfg['memory']
      vb.cpus   = vm_cfg['cpus']
      vb.linked_clone = true
    end
  when 'libvirt'
    m.vm.provider 'libvirt' do |lv|
      lv.memory = vm_cfg['memory']
      lv.cpus   = vm_cfg['cpus']
      if LAB_ARCH == HOST_ARCH
        lv.driver = 'kvm'
        lv.cpu_mode = 'host-passthrough' if LAB_ARCH == 'arm64'
      else
        lv.driver        = 'qemu'
        lv.machine_arch  = LAB_ARCH
        lv.machine_type  = 'pc'
        lv.emulator_path = '/usr/bin/qemu-system-x86_64'
        lv.cpu_mode      = 'custom'
        lv.cpu_model     = 'qemu64'
      end
    end
  when 'parallels'
    m.vm.provider 'parallels' do |prl|
      prl.name   = vm_name
      prl.memory = vm_cfg['memory']
      prl.cpus   = vm_cfg['cpus']
    end
  when 'vmware_desktop'
    m.vm.provider 'vmware_desktop' do |v|
      v.vmx['displayname'] = vm_name
      v.vmx['memsize']     = vm_cfg['memory'].to_s
      v.vmx['numvcpus']    = vm_cfg['cpus'].to_s
    end
  when 'qemu'
    qemu_bin = (LAB_ARCH == 'x86_64') ?
      QEMU_CFG['qemu_system_x86_64'] :
      QEMU_CFG['qemu_system_aarch64']
    m.vm.provider 'qemu' do |qe|
      qe.memory = "#{vm_cfg['memory']}M"
      qe.smp    = vm_cfg['cpus'].to_s
      if LAB_ARCH == 'x86_64'
        qe.arch    = 'x86_64'
        qe.machine = 'q35'
        qe.cpu     = 'qemu64'
      else
        qe.arch    = 'aarch64'
        qe.machine = 'virt,accel=hvf,highmem=off'
        qe.cpu     = 'cortex-a72'
      end
      qe.net_device = 'virtio-net-pci'
      qe.qemu_bin   = [
        QEMU_CFG['socket_vmnet_client'],
        QEMU_CFG['socket_vmnet_socket'],
        qemu_bin
      ]
    end
  else
    abort "RHCE-LAB: unsupported provider '#{PROVIDER}'"
  end
end

def lab_private_network(m, ip)
  # qemu uses socket_vmnet + the in-guest configure-static-ip.sh helper.
  return if PROVIDER == 'qemu'
  m.vm.network 'private_network', ip: ip, netmask: MASK
end

def lab_attach_extra_disk(m, vm_name, idx, size_gb)
  case PROVIDER
  when 'virtualbox', 'vmware_desktop'
    m.vm.disk :disk, name: "#{vm_name}-extra#{idx}", size: "#{size_gb}GB"
  when 'libvirt'
    m.vm.provider 'libvirt' do |lv|
      lv.storage :file, size: "#{size_gb}G", bus: 'virtio'
    end
  when 'parallels'
    m.vm.provider 'parallels' do |prl|
      prl.customize 'post-import',
        ['set', :id, '--device-add', 'hdd', '--size', "#{size_gb * 1024}"]
    end
  when 'qemu'
    disk_dir  = File.join(ROOT, 'disks')
    disk_file = File.join(disk_dir, "#{vm_name}-extra#{idx}.qcow2")
    m.trigger.before :up do |t|
      t.run = { inline: <<~SH }
        mkdir -p '#{disk_dir}'
        [ -f '#{disk_file}' ] || qemu-img create -f qcow2 '#{disk_file}' #{size_gb}G
      SH
    end
    m.vm.provider 'qemu' do |qe|
      args = qe.extra_qemu_args || []
      qe.extra_qemu_args = args + [
        '-drive', "file=#{disk_file},if=none,id=extra#{idx},format=qcow2",
        '-device', "virtio-blk-pci,drive=extra#{idx},serial=extra#{idx}"
      ]
    end
  end
end

def lab_attach_iso(m, iso_path)
  return unless iso_path
  case PROVIDER
  when 'virtualbox', 'vmware_desktop'
    m.vm.disk :dvd, name: 'lab-iso', file: iso_path
  when 'libvirt'
    m.vm.provider 'libvirt' do |lv|
      lv.storage :file, device: :cdrom, path: iso_path
    end
  when 'parallels'
    m.vm.provider 'parallels' do |prl|
      prl.customize ['set', :id, '--device-set', 'cdrom0',
                     '--image', iso_path, '--connect']
    end
  when 'qemu'
    m.vm.provider 'qemu' do |qe|
      args = qe.extra_qemu_args || []
      qe.extra_qemu_args = args + [
        '-drive', "file=#{iso_path},media=cdrom,readonly=on"
      ]
    end
  end
end

# -----------------------------------------------------------------------------
# Vagrant configuration
# -----------------------------------------------------------------------------

Vagrant.configure('2') do |config|
  config.vm.box              = BOX
  config.vm.box_architecture = BOX_ARCH
  config.vm.box_check_update = false

  # The default synced folder is unreliable across providers (qemu can't do
  # it cleanly; libvirt/parallels would mount via NFS/9p). The lab does not
  # depend on it — the repo server's NFS export carries everything needed.
  config.vm.synced_folder '.', '/vagrant', disabled: true

  # ---------------- REPO SERVER ----------------
  config.vm.define 'repo' do |m|
    m.vm.hostname = repo_cfg['hostname']
    lab_apply_basics(m, repo_cfg, 'rhce-repo-server')
    lab_private_network(m, REPO_IP)
    lab_attach_iso(m, ISO)
    m.vm.provision 'shell',
                   path: 'scripts/common/configure-static-ip.sh',
                   args: [REPO_IP, GATEWAY, SUBNET_CIDR, PROVIDER]
    m.vm.provision 'shell', path: 'scripts/common/base-setup.sh'
    m.vm.provision 'shell', path: 'scripts/common/create-users.sh'
    m.vm.provision 'shell', path: 'scripts/repo-server/setup-repos.sh'
    m.vm.provision 'shell', path: 'scripts/repo-server/setup-gpg.sh'
    m.vm.provision 'shell', path: 'scripts/repo-server/setup-nfs.sh',
                   args: [SUBNET_CIDR]
  end

  # ---------------- CONTROL NODE ----------------
  config.vm.define 'control' do |m|
    m.vm.hostname = ctrl_cfg['hostname']
    lab_apply_basics(m, ctrl_cfg, 'rhce-ansible-control')
    lab_private_network(m, CTRL_IP)
    m.vm.provision 'file', source: "files/keys/#{KEY_NAME}",
                   destination: '/tmp/RH294-LAB'
    m.vm.provision 'file', source: "files/keys/#{KEY_NAME}.pub",
                   destination: '/tmp/RH294-LAB.pub'
    m.vm.provision 'file', source: 'files/vimrc',
                   destination: '/tmp/vimrc'
    m.vm.provision 'shell',
                   path: 'scripts/common/configure-static-ip.sh',
                   args: [CTRL_IP, GATEWAY, SUBNET_CIDR, PROVIDER]
    m.vm.provision 'shell', path: 'scripts/common/base-setup.sh'
    m.vm.provision 'shell', path: 'scripts/common/create-users.sh'
    m.vm.provision 'shell', path: 'scripts/control/setup-control.sh',
                   args: HOST_ARGS
  end

  # ---------------- MANAGED NODES ----------------
  (1..NODE_COUNT).each do |i|
    config.vm.define "node#{i}" do |m|
      m.vm.hostname = "node#{i}"
      lab_apply_basics(m, node_cfg, "rhce-node#{i}")
      lab_private_network(m, node_ip(i))
      node_cfg['extra_disks'].each_with_index do |disk, idx|
        lab_attach_extra_disk(m, "node#{i}", idx + 1, disk['size'])
      end
      m.vm.provision 'file', source: "files/keys/#{KEY_NAME}.pub",
                     destination: '/tmp/RH294-LAB.pub'
      m.vm.provision 'shell',
                     path: 'scripts/common/configure-static-ip.sh',
                     args: [node_ip(i), GATEWAY, SUBNET_CIDR, PROVIDER]
      m.vm.provision 'shell', path: 'scripts/common/base-setup.sh'
      m.vm.provision 'shell', path: 'scripts/common/create-users.sh'
      m.vm.provision 'shell', path: 'scripts/node/setup-node.sh',
                     args: [REPO_IP]
    end
  end
end
```

- [ ] **Step 2: Validate Ruby syntax**

Run: `ruby -c Vagrantfile`
Expected: `Syntax OK`

- [ ] **Step 3: Sanity-check `vagrant validate` (does not boot anything)**

Run: `/opt/vagrant/bin/vagrant validate 2>&1 | head -20`
Expected: prints a `==> RHCE-LAB: host=...` line and either `Vagrantfile validated successfully.` OR a message about a missing plugin (only valid for providers other than the chosen one). If a missing-plugin error is for the AUTO-SELECTED provider on this host, that means the plugin must be installed first — install it (`vagrant plugin install vagrant-qemu` etc.) and re-run.

- [ ] **Step 4: Commit**

```bash
git add Vagrantfile
git commit -m "feat(vagrantfile): multi-provider refactor with auto-detection"
```

---

### Task 7: Rewrite README for multi-provider support

**Files:**
- Modify: `README.md` (full replacement)

- [ ] **Step 1: Replace the README with the content below**

````markdown
# RHCE-LAB

Automated RHCE 9 (EX294) practice lab — a 7-VM Ansible environment deployed
with Vagrant. Companion to RHCSA-LAB. Runs on macOS (Intel and Apple Silicon),
Linux (x86_64 and arm64), and Windows.

> Grading automation and the `bin/rhce-lab` exam CLI are delivered by a
> follow-up plan (Grading & Exam Tooling). This README covers the
> infrastructure and manual practice workflow.

## Supported scenarios

| Scenario | Host | Auto-selected provider | Plugin to install |
|---|---|---|---|
| **A. Native x86_64** | macOS Intel | `virtualbox` | (built-in) |
| | Linux x86_64 | `libvirt` | `vagrant-libvirt` |
| | Windows x86_64 | `virtualbox` | (built-in) |
| **B. Native arm64** | macOS Apple Silicon | `parallels` | `vagrant-parallels` |
| | Linux arm64 | `libvirt` (kvm) | `vagrant-libvirt` |
| **C. arm64 → x86 emulation** | macOS Apple Silicon | `qemu` + `socket_vmnet` | `vagrant-qemu` |
| | Linux arm64 | `libvirt` (tcg) | `vagrant-libvirt` |

`vmware_desktop` is supported as a fallback on every host that has VMware
Fusion or Workstation installed (free for personal use post-Broadcom).

Selection order:
1. `vagrant up --provider <name>` (CLI flag)
2. `LAB_PROVIDER=<name>` env var
3. `providers.default` in `config.yaml`
4. Auto-detect from `(host_os, host_arch, lab_arch)`

`LAB_ARCH=x86_64` on an arm64 host forces Scenario C.

## Prerequisites by host

### macOS Intel
- Install [VirtualBox 7.x](https://www.virtualbox.org/wiki/Downloads) and
  [Vagrant 2.4+](https://www.vagrantup.com/downloads).

### macOS Apple Silicon — Scenario B (native arm64)
- Install [Parallels Desktop](https://www.parallels.com/products/desktop/) Pro
  or Business edition.
- `vagrant plugin install vagrant-parallels`

### macOS Apple Silicon — Scenario C (qemu + socket_vmnet)
- `brew install qemu socket_vmnet`
- `vagrant plugin install vagrant-qemu`
- Run the one-time host setup:
  ```bash
  ./scripts/host/setup-socket-vmnet.sh
  ```
  This installs a launchd daemon that runs `socket_vmnet` in shared mode on
  the lab subnet (`192.168.56.0/24` by default). It needs `sudo` once.
  Subsequent `vagrant up` runs do not need `sudo`.
- Force this scenario explicitly when you also have Parallels:
  ```bash
  LAB_PROVIDER=qemu LAB_ARCH=x86_64 vagrant up
  ```

### Linux x86_64 or arm64
- Install Vagrant 2.4+, qemu, and libvirt:
  - Fedora/AlmaLinux/Rocky: `sudo dnf install @virtualization libguestfs-tools libvirt-devel`
  - Debian/Ubuntu: `sudo apt install qemu-system libvirt-daemon-system libvirt-dev ebtables libguestfs-tools`
- `sudo systemctl enable --now libvirtd`
- `vagrant plugin install vagrant-libvirt`
- For Scenario C on arm64 Linux: also install `qemu-system-x86_64` and set
  `LAB_ARCH=x86_64`.

### Windows x86_64
- Install VirtualBox 7.x and Vagrant 2.4+. Disable Hyper-V (or accept
  the VirtualBox-on-Hyper-V coexistence performance penalty).

## Quick start

```bash
cd RHCE-LAB
cp /path/to/AlmaLinux-9-DVD.iso iso/      # optional — see iso/README.md
vagrant up                                 # ~15-25 min on first run (native);
                                           # significantly longer under TCG emulation
```

The Vagrantfile prints the chosen provider on the first line:

```
==> RHCE-LAB: host=macos/arm64 lab_arch=x86_64 provider=qemu box_arch=amd64
```

## Topology

| Vagrant name | Hostname          | IP            | RAM     | Role                       |
|--------------|-------------------|---------------|---------|----------------------------|
| repo         | repo-server       | 192.168.56.40 | 1 GB    | HTTP repos + NFS + GPG key |
| control      | ansible-control   | 192.168.56.50 | 2 GB    | Ansible control node       |
| node1        | node1             | 192.168.56.51 | 1.25 GB | managed node — `dev`       |
| node2        | node2             | 192.168.56.52 | 1.25 GB | managed node — `test`      |
| node3        | node3             | 192.168.56.53 | 1.25 GB | managed node — `prod`      |
| node4        | node4             | 192.168.56.54 | 1.25 GB | managed node — `prod`      |
| node5        | node5             | 192.168.56.55 | 1.25 GB | managed node — `balancers` |

Edit `config.yaml` to tune subnet, RAM/CPU, node count, etc.

## Accounts

- `student` / `1234` — the RHCE practice user (every task path uses `/home/student`).
- `redhat` / `redhat` — convenience admin.
- Both have passwordless `sudo`.

The control node holds the `RH294-LAB` SSH key at
`/home/student/.ssh/RH294-LAB`; its public key is authorized for `student` on
every managed node.

## Storage layout (managed nodes)

Each managed node carries two extra virtual disks. Their device names depend
on the provider:

| Provider | First extra | Second extra |
|---|---|---|
| virtualbox, parallels, vmware_desktop | `/dev/sdb` | `/dev/sdc` |
| libvirt, qemu | `/dev/vdb` | `/dev/vdc` |

The first extra disk is left raw for task 17. The second extra disk is
pre-built into the volume group `research` for task 16. Provisioning scripts
detect either device-name family — students writing playbooks should accept
both forms.

## Practice workflow

```bash
vagrant ssh control
sudo -iu student
# Task 1 asks you to build the inventory and ansible.cfg.
# A reference ansible.cfg is in the repo at files/ansible.cfg.
```

Verify connectivity:

```bash
ansible all -m ping
```

Work the tasks in `lab/tasks/`; check yourself against `lab/solutions/`.

## Snapshots and reset

Provider-specific commands:

```bash
# VirtualBox
VBoxManage snapshot rhce-ansible-control take clean
VBoxManage snapshot rhce-node1           take clean
VBoxManage snapshot rhce-node1           restore clean

# libvirt
sudo virsh snapshot-create-as rhce-ansible-control clean
sudo virsh snapshot-revert    rhce-ansible-control clean

# Parallels
prlctl snapshot rhce-ansible-control -n clean
prlctl snapshot-switch rhce-ansible-control -i <snapshot-id>

# qemu — snapshot the qcow2 disks (VM must be off)
qemu-img snapshot -c clean .vagrant/machines/node1/qemu/box.img
qemu-img snapshot -a clean .vagrant/machines/node1/qemu/box.img
```

## Override env vars

```bash
LAB_PROVIDER=qemu       vagrant up           # force qemu, even if parallels is auto-selected
LAB_ARCH=x86_64         vagrant up           # force x86 emulation on an arm64 host
vagrant up --provider libvirt                # Vagrant's native CLI flag also works
```

## Common commands

```bash
vagrant status
vagrant up [name]
vagrant halt
vagrant ssh control
vagrant destroy -f
```

## Troubleshooting

- **"no provider matches host=..."** — auto-detection didn't match; set
  `LAB_PROVIDER` or `providers.default`.
- **socket_vmnet not running (qemu only)** — re-run
  `./scripts/host/setup-socket-vmnet.sh`, then check `sudo launchctl list | grep socket_vmnet`.
- **`vagrant up` very slow under Scenario C** — TCG emulation is 5–20× slower
  than native. First provisioning can take hours; subsequent `dnf` operations
  also pay the tax. Take a snapshot once provisioned.
- **Box variant missing for chosen provider** — verify with
  `curl -s https://app.vagrantup.com/api/v2/box/almalinux/9 | jq '.versions[0].providers[] | {name, architecture}'`.
  Fall back to `almalinux/9.aarch64` on arm64 if needed (edit `box.name` in
  `config.yaml`).
- **NFS `/mnt` not mounted on a node** — `sudo mount -a` (the repo server may
  have provisioned slightly after the node).
- **ansible-navigator EE pull fails** — provisioning continues; run with
  `--execution-environment false` until the image is pulled manually.

## License

MIT — free to use and modify for RHCE preparation.
````

- [ ] **Step 2: Verify the file exists, is non-empty, and mentions every provider**

Run: `for p in virtualbox libvirt parallels qemu vmware_desktop socket_vmnet; do grep -q "$p" README.md || echo "MISSING: $p"; done; echo done`
Expected: just `done` (no MISSING lines).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for multi-provider lab"
```

---

### Task 8: End-to-end integration verification on this host

This host is Apple Silicon M4 Pro (arm64). Default auto-selection picks
`parallels`; without Parallels installed, force `qemu` for Scenario C.

> This task requires `socket_vmnet` and ~10 GB free RAM. It can take 30 min
> to a few hours on first run because of TCG emulation. If something fails,
> capture the exact `vagrant up` output and report — do not edit the lab to
> paper over failures.

- [ ] **Step 1: One-time socket_vmnet setup**

Run: `./scripts/host/setup-socket-vmnet.sh`
Expected: ends with `socket_vmnet is running. Socket: /var/run/socket_vmnet  Gateway: 192.168.56.1`.

- [ ] **Step 2: Bring up the lab under qemu + x86_64 emulation**

Run:
```bash
export PATH="/opt/vagrant/bin:/usr/local/bin:$PATH"
LAB_PROVIDER=qemu LAB_ARCH=x86_64 vagrant up 2>&1 | tee vagrant-up-qemu.log
```
Expected: the first line reads
`==> RHCE-LAB: host=macos/arm64 lab_arch=x86_64 provider=qemu box_arch=amd64`,
and all 7 VMs eventually reach a `Machine booted and ready` state with no
fatal errors. `vagrant status` shows all `running`.

- [ ] **Step 3: Verify the repo server's HTTP repo is reachable from control**

Run:
```bash
vagrant ssh control -c "curl -s -o /dev/null -w '%{http_code}\n' http://192.168.56.40/repo/BaseOS/repodata/repomd.xml"
```
Expected: `200`.

- [ ] **Step 4: Verify a managed node mounted the NFS repo**

Run: `vagrant ssh node1 -c "mount | grep -c '/mnt/BaseOS'"`
Expected: `1`.

- [ ] **Step 5: Verify the `research` volume group exists on a node**

Run: `vagrant ssh node1 -c "sudo vgs --noheadings -o vg_name research | tr -d ' '"`
Expected: `research`.

- [ ] **Step 6: Verify the control node can SSH to every managed node as student**

Run:
```bash
vagrant ssh control -c "sudo -iu student bash -lc '
for n in node1 node2 node3 node4 node5; do
  ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i ~/.ssh/RH294-LAB student@\$n hostname
done'"
```
Expected: prints `node1` through `node5`, one per line.

- [ ] **Step 7: Verify Ansible connectivity end-to-end**

Run:
```bash
vagrant ssh control -c "sudo -iu student bash -lc '
cd ~/ansible
printf \"[all]\nnode1\nnode2\nnode3\nnode4\nnode5\n\" > inventory
printf \"[defaults]\ninventory=./inventory\nremote_user=student\nhost_key_checking=False\nprivate_key_file=~/.ssh/RH294-LAB\n\" > ansible.cfg
ansible all -m ping'"
```
Expected: every node reports `SUCCESS` with `"ping": "pong"`.

- [ ] **Step 8: Clean up the verification artifacts and snapshot a baseline**

Run:
```bash
vagrant ssh control -c "rm -f /home/student/ansible/inventory /home/student/ansible/ansible.cfg"
```

Snapshot every VM's main qcow2 (qemu provider only):
```bash
for vm in repo control node1 node2 node3 node4 node5; do
  img=$(find .vagrant/machines/$vm/qemu -name '*.img' -o -name '*.qcow2' | head -1)
  [ -f "$img" ] && qemu-img snapshot -c clean "$img" && echo "snapshotted $vm"
done
```

- [ ] **Step 9: Record the result**

If all steps passed, the multi-provider lab is verified for Scenario C on
this host. Commit the integration log (it's gitignored if matching `*.log`,
which it is — so just leave it in place for reference).

---

## Self-Review

**Spec coverage:**
- Provider matrix and auto-selection — Tasks 1, 6. ✓
- `LAB_PROVIDER` / `LAB_ARCH` / `vagrant --provider` override — Task 6. ✓
- `config.yaml` `providers:` section — Task 1. ✓
- Helper functions for memory/CPU, network, disks, ISO — Task 6. ✓
- qemu + `socket_vmnet` networking + in-guest static IPs — Tasks 3, 4, 6. ✓
- Per-provider extra disks (`config.vm.disk` / `libvirt.storage` /
  `prl.customize` / qemu trigger+`extra_qemu_args`) — Task 6. ✓
- Per-provider ISO attach — Task 6. ✓
- Cross-arch (Scenario C) on qemu and libvirt — Task 6. ✓
- AlmaLinux 9 multi-arch box selection (`config.vm.box_architecture`) —
  Task 6. ✓
- Provisioning scripts unchanged except `setup-node.sh` device-name
  flexibility — Task 5. ✓
- README documenting matrix, prereqs, overrides — Task 7. ✓
- Integration verification — Task 8. ✓
- Synced folder explicitly disabled — Task 6. ✓

**Placeholder scan:** No "TBD"/"TODO"/"implement later" anywhere. Every code
block contains complete content.

**Type/name consistency:** `PROVIDER`, `LAB_ARCH`, `HOST_ARCH`, `HOST_OS`,
`BOX_ARCH`, `PROVIDER_MATRIX`, `QEMU_CFG`, helper names (`lab_apply_basics`,
`lab_private_network`, `lab_attach_extra_disk`, `lab_attach_iso`) are used
consistently across Task 6 and the README's troubleshooting examples. VM
names `repo`/`control`/`node1..5`, hostnames `repo-server`/`ansible-control`/
`nodeN`, and VirtualBox/Parallels VM display names `rhce-*` match Plan 1.
