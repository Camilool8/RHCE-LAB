# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils'
require 'rbconfig'

ROOT     = File.dirname(__FILE__)
settings = YAML.load_file(File.join(ROOT, 'config.yaml'))

# -----------------------------------------------------------------------------
# Host + provider detection (native-arch only — guests match host arch)
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

# Native-arch only. Guests run on the host's CPU — no emulation.
PROVIDER_MATRIX = {
  %w[macos   x86_64] => 'virtualbox',
  %w[macos   arm64]  => 'parallels',
  %w[linux   x86_64] => 'libvirt',
  %w[linux   arm64]  => 'libvirt',
  %w[windows x86_64] => 'virtualbox',
}.freeze

def detect_cli_provider
  i = ARGV.index { |a| a == '--provider' || a.start_with?('--provider=') }
  return nil unless i
  arg = ARGV[i]
  return arg.split('=', 2)[1] if arg.include?('=')
  ARGV[i + 1]
end

cfg_default = settings.dig('providers', 'default').to_s.strip
PROVIDER = detect_cli_provider ||
           ENV['LAB_PROVIDER'] ||
           (cfg_default.empty? ? PROVIDER_MATRIX[[HOST_OS, HOST_ARCH]] : cfg_default)

if PROVIDER.nil? || PROVIDER.empty?
  abort "RHCE-LAB: no provider matches host=#{HOST_OS}/#{HOST_ARCH}.\n" \
        "Set LAB_PROVIDER, providers.default, or 'vagrant up --provider X'."
end

BOX_ARCH = (HOST_ARCH == 'x86_64') ? 'amd64' : 'arm64'

puts "==> RHCE-LAB: host=#{HOST_OS}/#{HOST_ARCH} provider=#{PROVIDER} box_arch=#{BOX_ARCH}"

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
      lv.memory   = vm_cfg['memory']
      lv.cpus     = vm_cfg['cpus']
      lv.driver   = 'kvm'
      lv.cpu_mode = 'host-passthrough' if HOST_ARCH == 'arm64'
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
  else
    abort "RHCE-LAB: unsupported provider '#{PROVIDER}'"
  end
end

def lab_private_network(m, ip)
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
  end
end

# -----------------------------------------------------------------------------
# Vagrant configuration
# -----------------------------------------------------------------------------

Vagrant.configure('2') do |config|
  config.vm.box              = BOX
  config.vm.box_architecture = BOX_ARCH
  config.vm.box_check_update = false

  # The default synced folder is unreliable across providers (libvirt/parallels
  # would mount via NFS/9p with extra requirements). The lab does not depend on
  # it — the repo server's NFS export carries everything needed.
  config.vm.synced_folder '.', '/vagrant', disabled: true

  # ---------------- REPO SERVER ----------------
  config.vm.define 'repo' do |m|
    m.vm.hostname = repo_cfg['hostname']
    lab_apply_basics(m, repo_cfg, 'rhce-repo-server')
    lab_private_network(m, REPO_IP)
    lab_attach_iso(m, ISO)
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
      m.vm.provision 'shell', path: 'scripts/common/base-setup.sh'
      m.vm.provision 'shell', path: 'scripts/common/create-users.sh'
      m.vm.provision 'shell', path: 'scripts/node/setup-node.sh',
                     args: [REPO_IP]
    end
  end
end
