# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils'
require 'rbconfig'

ROOT     = File.dirname(__FILE__)
settings = YAML.load_file(File.join(ROOT, 'config.yaml'))

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
  when 'x86_64', 'amd64', 'x64' then 'x86_64' # Vagrant's Ruby on Windows reports x64
  when 'arm64', 'aarch64'       then 'arm64'
  else RbConfig::CONFIG['host_cpu']
  end
end

HOST_OS   = detect_host_os
HOST_ARCH = detect_host_arch

def installed_macos_app?(path)
  File.exist?("/Applications/#{path}")
end

def installed_linux_binary?(name)
  ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? { |d| File.executable?(File.join(d, name)) }
end

def wsl?
  return false unless HOST_OS == 'linux'

  !ENV['WSL_DISTRO_NAME'].to_s.empty? ||
    (File.readable?('/proc/version') && File.read('/proc/version').include?('Microsoft'))
rescue StandardError
  false
end

def vboxmanage_binary_name
  (HOST_OS == 'windows' || wsl?) ? 'VBoxManage.exe' : 'VBoxManage'
end

def executable_at?(path)
  return false if path.nil? || path.to_s.strip.empty?
  return false unless File.exist?(path)

  return true if path =~ /\.exe\z/i
  File.executable?(path)
end

def vboxmanage_candidate_paths
  name = vboxmanage_binary_name
  paths = []

  ENV['PATH'].to_s.split(File::PATH_SEPARATOR).each do |d|
    next if d.nil? || d.strip.empty?

    paths << File.join(d.strip, name)
  end

  env_sep = HOST_OS == 'windows' ? ';' : File::PATH_SEPARATOR
  [ENV['VBOX_INSTALL_PATH'], ENV['VBOX_MSI_INSTALL_PATH']].each do |base|
    next if base.nil? || base.to_s.strip.empty?

    base.to_s.split(env_sep).each do |b|
      b = b.strip
      next if b.empty?

      paths << File.join(b, name)
    end
  end

  case HOST_OS
  when 'windows'
    drive = ENV['SYSTEMDRIVE'] || 'C:'
    pf    = ENV['ProgramFiles']
    pf86  = ENV['ProgramFiles(x86)']
    [
      File.join(drive, 'Program Files', 'Oracle', 'VirtualBox', name),
      File.join(drive, 'Program Files (x86)', 'Oracle', 'VirtualBox', name),
      (pf && !pf.empty? ? File.join(pf, 'Oracle', 'VirtualBox', name) : nil),
      (pf86 && !pf86.empty? ? File.join(pf86, 'Oracle', 'VirtualBox', name) : nil)
    ].compact.each { |p| paths << p }
  when 'linux'
    if wsl?
      [
        File.join('/mnt/c', 'Program Files', 'Oracle', 'VirtualBox', name),
        File.join('/mnt/c', 'Program Files (x86)', 'Oracle', 'VirtualBox', name)
      ].each { |p| paths << p }
    else
      ['/usr/bin', '/usr/local/bin', '/opt/VirtualBox'].each do |d|
        paths << File.join(d, name)
      end
    end
  when 'macos'
    paths << File.join('/Applications/VirtualBox.app/Contents/MacOS', name)
  end

  paths.uniq
end

def find_vboxmanage
  vboxmanage_candidate_paths.find { |p| executable_at?(p) }
end

def virtualbox_installed?
  return true if HOST_OS == 'macos' && installed_macos_app?('VirtualBox.app')

  !find_vboxmanage.nil?
end

def configure_vboxmanage_env!
  path = find_vboxmanage
  return unless path

  dir = File.dirname(path)
  sep = File::PATH_SEPARATOR
  expanded_dir = File.expand_path(dir)

  unless ENV['PATH'].to_s.split(sep).any? { |d| (File.expand_path(d) rescue d) == expanded_dir }
    ENV['PATH'] = "#{dir}#{sep}#{ENV['PATH']}"
  end

  ENV['VBOX_INSTALL_PATH'] ||= dir
  ENV['VBOX_MSI_INSTALL_PATH'] ||= dir if HOST_OS == 'windows'
end

configure_vboxmanage_env!

def detect_installed_provider
  case [HOST_OS, HOST_ARCH]
  when %w[macos x86_64]
    return 'virtualbox'     if virtualbox_installed?
    return 'vmware_desktop' if installed_macos_app?('VMware Fusion.app')
    'virtualbox'
  when %w[macos arm64]
    return 'parallels'      if installed_macos_app?('Parallels Desktop.app')
    return 'vmware_desktop' if installed_macos_app?('VMware Fusion.app')
    'parallels'
  when %w[linux x86_64], %w[linux arm64]
    return 'libvirt'        if installed_linux_binary?('virsh')
    return 'virtualbox'     if virtualbox_installed?
    'libvirt'
  when %w[windows x86_64]
    'virtualbox'
  end
end

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
           (cfg_default.empty? ? detect_installed_provider : cfg_default)

if PROVIDER.nil? || PROVIDER.empty?
  abort "RHCE-LAB: no provider matches host=#{HOST_OS}/#{HOST_ARCH}.\n" \
        "Set LAB_PROVIDER, providers.default, or 'vagrant up --provider X'."
end

BOX_ARCH = (HOST_ARCH == 'x86_64') ? 'amd64' : 'arm64'

puts "==> RHCE-LAB: host=#{HOST_OS}/#{HOST_ARCH} provider=#{PROVIDER} box_arch=#{BOX_ARCH}"

NET   = settings['network']['subnet']
MASK  = settings['network']['netmask']
BOX   = settings['box']['name']

repo_cfg = settings['vms']['repo_server']
ctrl_cfg = settings['vms']['control']
node_cfg = settings['vms']['nodes']

NODE_COUNT  = node_cfg['count']
NODE_BASE   = node_cfg['base_ip']
REPO_IP     = repo_cfg['ip']
CTRL_IP     = ctrl_cfg['ip']
SUBNET_CIDR = "#{NET}.0/24"

def node_ip(i)
  "#{NET}.#{NODE_BASE + i - 1}"
end

KEY_NAME = settings['lab']['ssh_key_name']
KEY_DIR  = File.join(ROOT, 'files', 'keys')
KEY_PRIV = File.join(KEY_DIR, KEY_NAME)
unless File.exist?(KEY_PRIV)
  FileUtils.mkdir_p(KEY_DIR)
  system("ssh-keygen -t rsa -b 2048 -N '' -C '#{KEY_NAME}' -f '#{KEY_PRIV}'")
end

HOST_ARGS = []
HOST_ARGS << REPO_IP << 'repo-server'
HOST_ARGS << CTRL_IP << 'ansible-control'
(1..NODE_COUNT).each { |i| HOST_ARGS << node_ip(i) << "node#{i}" }

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
  m.vm.network 'private_network', ip: ip, netmask: MASK, auto_config: false
end

def lab_attach_extra_disk(m, vm_name, idx, size_gb)
  case PROVIDER
  when 'virtualbox'
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
  when 'vmware_desktop'
    m.vm.disk :disk,
              name:    "#{vm_name}-extra#{idx}",
              size:    "#{size_gb}GB",
              primary: false,
              vmware_desktop: { bus_type: 'nvme' }
  end
end

Vagrant.configure('2') do |config|
  config.vm.box              = BOX
  config.vm.box_architecture = BOX_ARCH
  config.vm.box_check_update = false

  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.define 'repo' do |m|
    m.vm.hostname = repo_cfg['hostname']
    lab_apply_basics(m, repo_cfg, 'rhce-repo-server')
    lab_private_network(m, REPO_IP)
    (repo_cfg['extra_disks'] || []).each_with_index do |disk, idx|
      lab_attach_extra_disk(m, 'repo', idx + 1, disk['size'])
    end
    m.vm.provision 'shell', path: 'scripts/common/base-setup.sh',
                   args: [SUBNET_CIDR]
    m.vm.provision 'shell', path: 'scripts/common/configure-lab-network.sh',
                   args: [REPO_IP, SUBNET_CIDR]
    m.vm.provision 'shell', path: 'scripts/common/create-users.sh'
    m.vm.provision 'shell', path: 'scripts/repo-server/setup-repos.sh'
    m.vm.provision 'shell', path: 'scripts/repo-server/setup-gpg.sh'
    m.vm.provision 'shell', path: 'scripts/repo-server/setup-nfs.sh',
                   args: [SUBNET_CIDR]
  end

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
    m.vm.provision 'file', source: 'scripts/verify',
                   destination: '/tmp/verify'
    m.vm.provision 'shell', path: 'scripts/common/base-setup.sh',
                   args: [SUBNET_CIDR]
    m.vm.provision 'shell', path: 'scripts/common/configure-lab-network.sh',
                   args: [CTRL_IP, SUBNET_CIDR]
    m.vm.provision 'shell', path: 'scripts/common/create-users.sh'
    m.vm.provision 'shell', path: 'scripts/control/setup-control.sh',
                   args: HOST_ARGS
  end

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
      m.vm.provision 'shell', path: 'scripts/common/base-setup.sh',
                     args: [SUBNET_CIDR]
      m.vm.provision 'shell', path: 'scripts/common/configure-lab-network.sh',
                     args: [node_ip(i), SUBNET_CIDR]
      m.vm.provision 'shell', path: 'scripts/common/create-users.sh'
      m.vm.provision 'shell', path: 'scripts/node/setup-node.sh',
                     args: [REPO_IP]
    end
  end
end
