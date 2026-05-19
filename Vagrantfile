# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils'

ROOT     = File.dirname(__FILE__)
settings = YAML.load_file(File.join(ROOT, 'config.yaml'))

NET   = settings['network']['subnet']
MASK  = settings['network']['netmask']
BOX   = settings['box']['name']
ISO   = Dir.glob(File.join(ROOT, 'iso', '*.iso')).first

repo_cfg = settings['vms']['repo_server']
ctrl_cfg = settings['vms']['control']
node_cfg = settings['vms']['nodes']

NODE_COUNT  = node_cfg['count']
NODE_BASE   = node_cfg['base_ip']
REPO_IP     = repo_cfg['ip']
CTRL_IP     = ctrl_cfg['ip']
SUBNET_CIDR = "#{NET}.0/24"

def node_ip(i)
  # NET and NODE_BASE are top-level constants, in scope inside methods.
  "#{NET}.#{NODE_BASE + i - 1}"
end

# --- Generate the RH294-LAB keypair on the host once ---
KEY_NAME = settings['lab']['ssh_key_name']
KEY_DIR  = File.join(ROOT, 'files', 'keys')
KEY_PRIV = File.join(KEY_DIR, KEY_NAME)
unless File.exist?(KEY_PRIV)
  FileUtils.mkdir_p(KEY_DIR)
  system("ssh-keygen -t rsa -b 2048 -N '' -C '#{KEY_NAME}' -f '#{KEY_PRIV}'")
end

# --- "<ip> <hostname>" args for the control node's /etc/hosts ---
HOST_ARGS = []
HOST_ARGS << REPO_IP << 'repo-server'
HOST_ARGS << CTRL_IP << 'ansible-control'
(1..NODE_COUNT).each { |i| HOST_ARGS << node_ip(i) << "node#{i}" }

def attach_iso(vb, iso)
  return unless iso
  vb.customize ['storageattach', :id,
                '--storagectl', 'IDE Controller',
                '--port', 1, '--device', 0,
                '--type', 'dvddrive',
                '--medium', File.absolute_path(iso)]
end

Vagrant.configure('2') do |config|
  config.vm.box = BOX
  config.vm.box_check_update = false

  config.vm.provider 'virtualbox' do |vb|
    vb.gui = false
    vb.linked_clone = true
  end

  # ---------------- REPO SERVER ----------------
  config.vm.define 'repo' do |m|
    m.vm.hostname = repo_cfg['hostname']
    m.vm.network 'private_network', ip: REPO_IP, netmask: MASK
    m.vm.provider 'virtualbox' do |vb|
      vb.name   = 'rhce-repo-server'
      vb.memory = repo_cfg['memory']
      vb.cpus   = repo_cfg['cpus']
      attach_iso(vb, ISO)
    end
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
    m.vm.network 'private_network', ip: CTRL_IP, netmask: MASK
    m.vm.provider 'virtualbox' do |vb|
      vb.name   = 'rhce-ansible-control'
      vb.memory = ctrl_cfg['memory']
      vb.cpus   = ctrl_cfg['cpus']
    end
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
      m.vm.network 'private_network', ip: node_ip(i), netmask: MASK
      m.vm.provider 'virtualbox' do |vb|
        vb.name   = "rhce-node#{i}"
        vb.memory = node_cfg['memory']
        vb.cpus   = node_cfg['cpus']
        node_cfg['extra_disks'].each_with_index do |disk, idx|
          disk_file = File.join(ROOT, 'disks', "node#{i}-disk#{idx + 1}.vdi")
          unless File.exist?(disk_file)
            FileUtils.mkdir_p(File.join(ROOT, 'disks'))
            vb.customize ['createhd', '--filename', disk_file,
                          '--size', disk['size'].to_i * 1024]
            vb.customize ['storageattach', :id,
                          '--storagectl', 'SATA Controller',
                          '--port', idx + 1, '--device', 0,
                          '--type', 'hdd', '--medium', disk_file]
          end
        end
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
