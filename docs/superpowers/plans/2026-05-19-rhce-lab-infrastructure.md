# RHCE-LAB Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Vagrant + VirtualBox lab that deploys a 7-VM Ansible practice environment for the RHCE 9 (EX294) exam with a single `vagrant up`.

**Architecture:** A `config.yaml`-driven Vagrantfile provisions a repo server, an Ansible control node, and five managed nodes. Shell scripts handle per-role provisioning (repos, NFS, users, SSH keys, storage). An `RH294-LAB` SSH keypair is generated on the host and distributed so the control node can manage the nodes out of the box. The upstream `rhce9-ex294-practice-lab-main` tasks/solutions are copied into `lab/`.

**Tech Stack:** Vagrant, VirtualBox, AlmaLinux 9 box, Bash provisioning scripts, Ruby (Vagrantfile), YAML config.

**Testing note:** This is infrastructure code. There is no unit-test harness, and spinning up 7 VMs per step is impractical. Each file task is verified by static validation (`bash -n` for shell, `ruby -c` for the Vagrantfile, YAML parse for config). A single end-to-end integration task at the end performs the real `vagrant up` and connectivity check.

**Prerequisite context for the engineer:** The upstream content lives at `/Users/cjoga/Labs/rhce9-ex294-practice-lab-main/`. The lab being built lives at `/Users/cjoga/Labs/RHCE-LAB/` (already a git repo with `.gitignore` and `docs/`). All paths below are relative to `/Users/cjoga/Labs/RHCE-LAB/` unless absolute.

---

### Task 1: Lab configuration file

**Files:**
- Create: `config.yaml`

- [ ] **Step 1: Write `config.yaml`**

```yaml
# RHCE-LAB Configuration — edit values here, then `vagrant up`.

network:
  subnet: "192.168.56"          # private lab network (third octet free to change)
  netmask: "255.255.255.0"

vms:
  repo_server:
    hostname: "repo-server"
    ip: "192.168.56.40"
    memory: 1024
    cpus: 2
  control:
    hostname: "ansible-control"
    ip: "192.168.56.50"
    memory: 2048
    cpus: 2
  nodes:
    count: 5                    # number of managed nodes (node1..nodeN)
    base_ip: 51                 # node1 = subnet.51, node2 = subnet.52, ...
    memory: 1280
    cpus: 1
    extra_disks:
      - size: 2                 # /dev/sdb — raw, used by task 17
      - size: 2                 # /dev/sdc — built into VG 'research', task 16

box:
  name: "almalinux/9"

lab:
  ansible_user: "student"
  ssh_key_name: "RH294-LAB"
  time_server: "172.25.254.250"
```

- [ ] **Step 2: Validate the YAML parses**

Run: `ruby -ryaml -e "YAML.load_file('config.yaml'); puts 'OK'"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add config.yaml
git commit -m "feat: add lab configuration file"
```

---

### Task 2: ISO folder placeholder

**Files:**
- Create: `iso/README.md`

- [ ] **Step 1: Write `iso/README.md`**

```markdown
# ISO Folder

Drop a RHEL 9 or AlmaLinux 9 **DVD ISO** here (optional).

- **With an ISO present:** the repo server copies the full BaseOS and
  AppStream package trees from the ISO. The lab then has a complete offline
  package mirror.
- **Without an ISO:** the repo server creates empty-but-valid BaseOS and
  AppStream repository structures (enough for task 2's `file://` repo task).
  Managed nodes use the AlmaLinux internet mirrors for actual package
  installs, so an internet connection is needed during practice.

Only the first `*.iso` file found here is used.
```

- [ ] **Step 2: Verify the file exists**

Run: `test -f iso/README.md && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add iso/README.md
git commit -m "docs: add iso folder placeholder"
```

---

### Task 3: Static files (vimrc + sample ansible.cfg)

**Files:**
- Create: `files/vimrc`
- Create: `files/ansible.cfg`

- [ ] **Step 1: Write `files/vimrc`**

```vim
" RHCE-LAB Vim configuration for Ansible playbook editing
let mapleader = " "

nmap <leader>w :w<CR>
nmap <leader>wq :wq<CR>
nmap <leader>q :q<CR>
nmap <leader>Q :q!<CR>

set cuc
set cul
set nu
set ai

set et
set sw=2
set ts=2
set sts=2

set fdm=indent
set fdl=99
set hls
set ic
set is

syntax on

" <Space>K shows ansible-doc for the module under the cursor in a vsplit
nnoremap <leader>K :set splitright<CR>:vnew<CR>:setlocal buftype=nofile<CR>:r! ansible-doc <C-R><C-W><CR>
```

- [ ] **Step 2: Write `files/ansible.cfg`**

```ini
# Sample ansible.cfg for reference (RHCE-LAB).
# Task 1 asks you to create your own at /home/student/ansible/ansible.cfg.
[defaults]
inventory = ./inventory
roles_path = ./roles
collections_path = ./mycollection
remote_user = student
host_key_checking = False
private_key_file = ~/.ssh/RH294-LAB

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

- [ ] **Step 3: Verify both files exist**

Run: `test -f files/vimrc && test -f files/ansible.cfg && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add files/vimrc files/ansible.cfg
git commit -m "feat: add vimrc and sample ansible.cfg"
```

---

### Task 4: Common base-setup provisioning script

**Files:**
- Create: `scripts/common/base-setup.sh`

- [ ] **Step 1: Write `scripts/common/base-setup.sh`**

```bash
#!/bin/bash
# Base setup applied to every VM in the lab.
set -euo pipefail

echo "=== Base setup: $(hostname) ==="

dnf install -y vim wget curl net-tools bind-utils tar bash-completion \
  2>/dev/null || echo "WARN: some base packages may already be installed"

systemctl enable --now firewalld

echo "=== Base setup complete: $(hostname) ==="
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/common/base-setup.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/common/base-setup.sh
git add scripts/common/base-setup.sh
git commit -m "feat: add common base-setup provisioning script"
```

---

### Task 5: Common user-creation provisioning script

**Files:**
- Create: `scripts/common/create-users.sh`

- [ ] **Step 1: Write `scripts/common/create-users.sh`**

```bash
#!/bin/bash
# Creates the lab user accounts on every VM:
#   student / 1234   (mandatory — all RHCE task paths use /home/student)
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

create_user student 1234
create_user redhat redhat

# Enable password SSH (lab convenience).
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config
if [ -d /etc/ssh/sshd_config.d ]; then
  echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/01-lab.conf
fi
systemctl restart sshd

echo "=== Lab users created on $(hostname) ==="
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/common/create-users.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/common/create-users.sh
git add scripts/common/create-users.sh
git commit -m "feat: add common user-creation provisioning script"
```

---

### Task 6: Repo-server HTTP repository script

**Files:**
- Create: `scripts/repo-server/setup-repos.sh`

- [ ] **Step 1: Write `scripts/repo-server/setup-repos.sh`**

```bash
#!/bin/bash
# Repo server: build BaseOS/AppStream HTTP repositories.
# If a DVD ISO is attached (/dev/sr0) its content is copied; otherwise
# empty-but-valid repo structures are created.
set -euo pipefail

echo "=== Repo server: HTTP repositories ==="

WEBROOT=/var/www/html/repo
mkdir -p "$WEBROOT/BaseOS" "$WEBROOT/AppStream"

dnf install -y httpd createrepo_c

ISO_FOUND=false
if [ -b /dev/sr0 ]; then
  mkdir -p /mnt/iso
  if mount -o ro /dev/sr0 /mnt/iso 2>/dev/null \
     && [ -d /mnt/iso/BaseOS ] && [ -d /mnt/iso/AppStream ]; then
    echo "ISO detected — copying BaseOS/AppStream (this can take several minutes)"
    cp -a /mnt/iso/BaseOS/. "$WEBROOT/BaseOS/"
    cp -a /mnt/iso/AppStream/. "$WEBROOT/AppStream/"
    ISO_FOUND=true
    umount /mnt/iso
  fi
fi

if [ "$ISO_FOUND" = false ]; then
  echo "No ISO — creating empty repo structure."
  echo "Managed nodes will use AlmaLinux internet repos for package installs."
fi

[ -d "$WEBROOT/BaseOS/repodata" ]    || createrepo_c "$WEBROOT/BaseOS"
[ -d "$WEBROOT/AppStream/repodata" ] || createrepo_c "$WEBROOT/AppStream"

cat > /etc/httpd/conf.d/repo.conf <<'EOF'
Alias /repo /var/www/html/repo
<Directory /var/www/html/repo>
    Options Indexes FollowSymLinks
    Require all granted
</Directory>
EOF

chown -R apache:apache "$WEBROOT"
restorecon -R "$WEBROOT" 2>/dev/null || true

firewall-cmd --permanent --add-service=http
firewall-cmd --reload
systemctl enable --now httpd

echo "=== HTTP repos ready at http://<repo-ip>/repo/ ==="
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/repo-server/setup-repos.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/repo-server/setup-repos.sh
git add scripts/repo-server/setup-repos.sh
git commit -m "feat: add repo-server HTTP repository script"
```

---

### Task 7: Repo-server GPG key publishing script

**Files:**
- Create: `scripts/repo-server/setup-gpg.sh`

- [ ] **Step 1: Write `scripts/repo-server/setup-gpg.sh`**

```bash
#!/bin/bash
# Repo server: publish the AlmaLinux GPG key over HTTP.
# (The key also already exists on every AlmaLinux node at the path
#  task 2 expects: /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9.)
set -euo pipefail

echo "=== Repo server: publish GPG key ==="

KEY=/etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9
if [ -f "$KEY" ]; then
  cp "$KEY" /var/www/html/repo/RPM-GPG-KEY-AlmaLinux-9
  echo "Published $KEY -> /repo/RPM-GPG-KEY-AlmaLinux-9"
else
  echo "WARN: $KEY not found on repo server"
fi

echo "=== GPG key step complete ==="
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/repo-server/setup-gpg.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/repo-server/setup-gpg.sh
git add scripts/repo-server/setup-gpg.sh
git commit -m "feat: add repo-server GPG key publishing script"
```

---

### Task 8: Repo-server NFS export script

**Files:**
- Create: `scripts/repo-server/setup-nfs.sh`

- [ ] **Step 1: Write `scripts/repo-server/setup-nfs.sh`**

```bash
#!/bin/bash
# Repo server: NFS-export the BaseOS/AppStream trees so managed nodes can
# mount them at /mnt/BaseOS and /mnt/AppStream (needed by task 2).
# Arg 1: subnet CIDR allowed to mount (e.g. 192.168.56.0/24).
set -euo pipefail

SUBNET="${1:?subnet CIDR argument required}"
WEBROOT=/var/www/html/repo

echo "=== Repo server: NFS exports for ${SUBNET} ==="

dnf install -y nfs-utils

cat > /etc/exports <<EOF
${WEBROOT}/BaseOS    ${SUBNET}(ro,sync,no_root_squash)
${WEBROOT}/AppStream ${SUBNET}(ro,sync,no_root_squash)
EOF

firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload

systemctl enable --now nfs-server
exportfs -rav

echo "=== NFS exports ready ==="
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/repo-server/setup-nfs.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/repo-server/setup-nfs.sh
git add scripts/repo-server/setup-nfs.sh
git commit -m "feat: add repo-server NFS export script"
```

---

### Task 9: Managed-node provisioning script

**Files:**
- Create: `scripts/node/setup-node.sh`

- [ ] **Step 1: Write `scripts/node/setup-node.sh`**

```bash
#!/bin/bash
# Managed node setup: authorize the control node's SSH key, prepare extra
# storage, and mount the BaseOS/AppStream repos from the repo server.
# Arg 1: repo server IP.
set -euo pipefail

REPO_IP="${1:?repo server IP argument required}"

echo "=== Managed node setup: $(hostname) ==="

# --- Ansible-managed-node prerequisites ---
dnf install -y python3 lvm2 nfs-utils

# --- Authorize the RH294-LAB key for student (uploaded to /tmp by Vagrant) ---
install -d -m 700 -o student -g student /home/student/.ssh
touch /home/student/.ssh/authorized_keys
cat /tmp/RH294-LAB.pub >> /home/student/.ssh/authorized_keys
sort -u /home/student/.ssh/authorized_keys -o /home/student/.ssh/authorized_keys
chown student:student /home/student/.ssh/authorized_keys
chmod 600 /home/student/.ssh/authorized_keys
restorecon -R /home/student/.ssh 2>/dev/null || true

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

# --- Mount BaseOS/AppStream from the repo server at /mnt (task 2) ---
mkdir -p /mnt/BaseOS /mnt/AppStream
for share in BaseOS AppStream; do
  fstab_line="${REPO_IP}:/var/www/html/repo/${share} /mnt/${share} nfs ro,_netdev 0 0"
  grep -qF " /mnt/${share} nfs " /etc/fstab \
    || echo "$fstab_line" >> /etc/fstab
done
mount -a || echo "WARN: NFS mount deferred (repo server may not be ready yet)"

echo "=== Managed node setup complete: $(hostname) ==="
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/node/setup-node.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/node/setup-node.sh
git add scripts/node/setup-node.sh
git commit -m "feat: add managed-node provisioning script"
```

---

### Task 10: Control-node provisioning script

**Files:**
- Create: `scripts/control/setup-control.sh`

- [ ] **Step 1: Write `scripts/control/setup-control.sh`**

```bash
#!/bin/bash
# Control node setup: install Ansible tooling, install the RH294-LAB private
# key for student, populate /etc/hosts, and pre-pull an execution environment.
# Args: repeated "<ip> <hostname>" pairs for every lab host.
set -euo pipefail

echo "=== Control node setup ==="

# --- Ansible tooling ---
dnf install -y ansible-core python3 python3-pip podman git tar 2>/dev/null \
  || echo "WARN: some control packages may already be installed"
dnf install -y ansible-navigator 2>/dev/null || true
if ! command -v ansible-navigator &>/dev/null; then
  pip3 install ansible-navigator 2>/dev/null \
    || echo "WARN: ansible-navigator not installed (task 18 may need manual setup)"
fi

# --- RH294-LAB SSH key for student (uploaded to /tmp by Vagrant) ---
install -d -m 700 -o student -g student /home/student/.ssh
install -m 600 -o student -g student /tmp/RH294-LAB     /home/student/.ssh/RH294-LAB
install -m 644 -o student -g student /tmp/RH294-LAB.pub /home/student/.ssh/RH294-LAB.pub
restorecon -R /home/student/.ssh 2>/dev/null || true

# --- Working directory and vimrc helper ---
install -d -m 755 -o student -g student /home/student/ansible
install -m 644 -o student -g student /tmp/vimrc /home/student/.vimrc

# --- /etc/hosts: args are repeated "<ip> <hostname>" pairs ---
sed -i '/# RHCE-LAB BEGIN/,/# RHCE-LAB END/d' /etc/hosts
{
  echo "# RHCE-LAB BEGIN"
  while [ "$#" -ge 2 ]; do
    ip="$1"; host="$2"; shift 2
    echo "${ip} ${host} ${host}.example.com ansible-${host}"
  done
  echo "# RHCE-LAB END"
} >> /etc/hosts

# --- Pre-pull an execution environment for ansible-navigator (task 18) ---
sudo -u student podman pull quay.io/ansible/creator-ee:latest 2>/dev/null \
  || echo "WARN: EE image pull failed — run ansible-navigator with '--execution-environment false'"

echo "=== Control node setup complete ==="
```

- [ ] **Step 2: Validate shell syntax**

Run: `bash -n scripts/control/setup-control.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/control/setup-control.sh
git add scripts/control/setup-control.sh
git commit -m "feat: add control-node provisioning script"
```

---

### Task 11: Vagrantfile

**Files:**
- Create: `Vagrantfile`

- [ ] **Step 1: Write `Vagrantfile`**

```ruby
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
```

- [ ] **Step 2: Validate Ruby syntax**

Run: `ruby -c Vagrantfile`
Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add Vagrantfile
git commit -m "feat: add Vagrantfile defining the 7-VM lab topology"
```

---

### Task 12: Import upstream tasks and solutions into `lab/`

**Files:**
- Create: `lab/tasks/task-01.txt` ... `lab/tasks/task-18.txt` (copied)
- Create: `lab/solutions/answer-01.md` ... `lab/solutions/answer-18.md` (copied + adapted)

- [ ] **Step 1: Copy the upstream task files verbatim**

The upstream task files already use `node1`..`node5`, matching this lab's inventory, so they are copied unchanged.

```bash
mkdir -p lab/tasks lab/solutions
cp /Users/cjoga/Labs/rhce9-ex294-practice-lab-main/tasks/task-*.txt lab/tasks/
```

- [ ] **Step 2: Copy the upstream solutions, adapting hostnames**

The upstream solutions refer to managed nodes as `ansible-node-1`..`ansible-node-5`. This lab uses `node1`..`node5`. Copy each solution with that substitution.

```bash
for f in /Users/cjoga/Labs/rhce9-ex294-practice-lab-main/solutions/answer-*.md; do
  sed 's/ansible-node-/node/g' "$f" > "lab/solutions/$(basename "$f")"
done
```

- [ ] **Step 3: Verify counts**

Run: `ls lab/tasks/*.txt | wc -l; ls lab/solutions/*.md | wc -l`
Expected: `18` then `18`

- [ ] **Step 4: Commit**

```bash
git add lab/tasks lab/solutions
git commit -m "feat: import RHCE practice tasks and solutions into lab/"
```

---

### Task 13: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

````markdown
# RHCE-LAB

Automated RHCE 9 (EX294) practice lab — a 7-VM Ansible environment deployed
with Vagrant + VirtualBox. Companion to RHCSA-LAB.

> Grading automation and the `bin/rhce-lab` exam CLI are delivered by a
> follow-up plan (Grading & Exam Tooling). This README covers the
> infrastructure and manual practice workflow.

## Prerequisites

- VirtualBox 7.0+
- Vagrant 2.4+
- Host resources: ~10 GB free RAM, ~80 GB disk, virtualization enabled
- Internet access on first `vagrant up` (box download, packages, task 6
  Galaxy roles, task 18 execution-environment image)

## Topology

| VM       | Hostname          | IP             | RAM     | Role                         |
|----------|-------------------|----------------|---------|------------------------------|
| repo     | repo-server       | 192.168.56.40  | 1 GB    | HTTP repos + NFS + GPG key   |
| control  | ansible-control   | 192.168.56.50  | 2 GB    | Ansible control node         |
| node1    | node1             | 192.168.56.51  | 1.25 GB | managed node — group `dev`   |
| node2    | node2             | 192.168.56.52  | 1.25 GB | managed node — group `test`  |
| node3    | node3             | 192.168.56.53  | 1.25 GB | managed node — group `prod`  |
| node4    | node4             | 192.168.56.54  | 1.25 GB | managed node — group `prod`  |
| node5    | node5             | 192.168.56.55  | 1.25 GB | managed node — group `balancers` |

All values are tunable in `config.yaml`.

## Quick Start

```bash
cd RHCE-LAB
cp /path/to/AlmaLinux-9-DVD.iso iso/      # optional — see iso/README.md
vagrant up                                 # 15-25 min on first run
```

## Accounts

- `student` / `1234` — the RHCE practice user (all task paths use `/home/student`)
- `redhat` / `redhat` — convenience admin account
- Both have passwordless `sudo`.

The control node holds the `RH294-LAB` SSH key at
`/home/student/.ssh/RH294-LAB`; its public key is authorized for `student` on
every managed node.

## Practice Workflow

```bash
vagrant ssh control
sudo -iu student          # become the practice user

# Task 1 asks you to build the inventory and ansible.cfg.
# A reference ansible.cfg is in the repo at files/ansible.cfg.
```

Verify connectivity once your inventory exists:

```bash
ansible all -m ping
```

Work the tasks in `lab/tasks/`; check yourself against `lab/solutions/`.

### Snapshots and reset

```bash
# Take a clean baseline after first provisioning
VBoxManage snapshot rhce-ansible-control snapshot take clean
VBoxManage snapshot rhce-node1 snapshot take clean
# ... repeat for node2..node5 and rhce-repo-server

# Restore
VBoxManage snapshot rhce-node1 snapshot restore clean
vagrant up node1
```

## Repositories

- `http://192.168.56.40/repo/BaseOS/` and `/AppStream/` — HTTP repos.
- Each managed node NFS-mounts those trees at `/mnt/BaseOS` and
  `/mnt/AppStream` (used by task 2's `file://` repositories).
- With an ISO in `iso/`, the repos hold the full package set. Without one,
  they are empty-but-valid structures and nodes use AlmaLinux internet repos.

## Storage layout (managed nodes)

- `/dev/sdb` — 2 GB, raw/unpartitioned — used by task 17.
- `/dev/sdc` — 2 GB, pre-built into volume group `research` — used by task 16.

## Common Commands

```bash
vagrant status
vagrant up [name]
vagrant halt
vagrant ssh control
vagrant destroy -f
VBoxManage snapshot <vm> snapshot list
```

## Troubleshooting

- **ISO not detected:** confirm a single `*.iso` in `iso/`, then
  `vagrant reload --provision repo`.
- **`ansible all -m ping` fails:** confirm your inventory uses `node1`..`node5`
  and `ansible.cfg` sets `private_key_file = ~/.ssh/RH294-LAB`.
- **NFS `/mnt` not mounted on a node:** `sudo mount -a` (the repo server may
  have provisioned after the node).
- **ISO attach fails on `vagrant up`:** the box may name its storage
  controller differently; adjust `--storagectl` in the Vagrantfile.

## License

MIT — free to use and modify for RHCE preparation.
````

- [ ] **Step 2: Verify the file exists and is non-empty**

Run: `test -s README.md && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add RHCE-LAB README"
```

---

### Task 14: End-to-end integration verification

**Files:** none created — this task runs the real lab.

> This task requires VirtualBox and Vagrant installed and ~10 GB free RAM.
> It takes 15-25 minutes. If the environment cannot run it, mark the task
> blocked and report — do not fake the result.

- [ ] **Step 1: Bring up the full lab**

Run: `vagrant up`
Expected: all 7 VMs (`repo`, `control`, `node1`..`node5`) finish provisioning
with no fatal errors. `vagrant status` shows all `running`.

- [ ] **Step 2: Verify the repo server serves HTTP repos**

Run: `vagrant ssh control -c "curl -s -o /dev/null -w '%{http_code}\n' http://192.168.56.40/repo/BaseOS/repodata/repomd.xml"`
Expected: `200`

- [ ] **Step 3: Verify a managed node mounted the NFS repos**

Run: `vagrant ssh node1 -c "mount | grep -c '/mnt/BaseOS'"`
Expected: `1`

- [ ] **Step 4: Verify the `research` volume group exists on a node**

Run: `vagrant ssh node1 -c "sudo vgs --noheadings -o vg_name research | tr -d ' '"`
Expected: `research`

- [ ] **Step 5: Verify the control node can SSH to every managed node as student**

Run:
```bash
vagrant ssh control -c "sudo -iu student bash -lc '
for n in node1 node2 node3 node4 node5; do
  ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i ~/.ssh/RH294-LAB student@\$n hostname
done'"
```
Expected: prints `node1` through `node5`, one per line.

- [ ] **Step 6: Verify Ansible connectivity end-to-end**

Run:
```bash
vagrant ssh control -c "sudo -iu student bash -lc '
cd ~/ansible
printf \"[all]\nnode1\nnode2\nnode3\nnode4\nnode5\n\" > inventory
printf \"[defaults]\ninventory=./inventory\nremote_user=student\nhost_key_checking=False\nprivate_key_file=~/.ssh/RH294-LAB\n\" > ansible.cfg
ansible all -m ping'"
```
Expected: every node reports `SUCCESS` with `"ping": "pong"`.

- [ ] **Step 7: Clean up the verification inventory and commit nothing**

Run:
```bash
vagrant ssh control -c "rm -f /home/student/ansible/inventory /home/student/ansible/ansible.cfg"
```
Expected: no output. (These were scratch files for the test; the lab leaves
`/home/student/ansible/` empty for the user to build in task 1.)

- [ ] **Step 8: Record the result**

If all steps passed, the lab infrastructure is verified. Take a clean
snapshot baseline:

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 rhce-node3 rhce-node4 rhce-node5; do
  VBoxManage snapshot "$vm" take clean
done
```

---

## Self-Review

**Spec coverage:**
- Topology (7 VMs, IPs, RAM) — Tasks 1, 11. ✓
- Baked-in inventory groups — managed nodes are plain hosts; group membership
  is the student's job in task 1. The lab provides resolvable `node1`..`node5`
  (Task 10 `/etc/hosts`). ✓
- Users `student`/`redhat` — Task 5. ✓
- `RH294-LAB` keypair generated on host and distributed — Tasks 9, 10, 11. ✓
- AlmaLinux box + ISO auto-detect — Tasks 1, 6, 11. ✓
- HTTP + NFS repos, `/mnt/BaseOS` on nodes — Tasks 6, 8, 9. ✓
- GPG key staged — Task 7 (publish) + already present on AlmaLinux nodes. ✓
- Two extra disks per node, `research` VG — Tasks 9, 11. ✓
- EE pre-pull for task 18 — Task 10. ✓
- `lab/tasks` + `lab/solutions` — Task 12. ✓
- README — Task 13. ✓
- Grading harness, `bin/rhce-lab` CLI, exam mode, `exam-blueprint.md` —
  **deferred to Plan 2 (Grading & Exam Tooling)**, as stated in the plan header.

**Placeholder scan:** No TBD/TODO. EE image tag `quay.io/ansible/creator-ee:latest`
is wrapped in a non-fatal `|| echo WARN` with a documented fallback, matching
the spec's open follow-up.

**Type/name consistency:** VM definition names (`repo`, `control`, `node1..5`),
VirtualBox names (`rhce-*`), hostnames, and the `RH294-LAB` key name are used
consistently across config, Vagrantfile, scripts, README, and verification.
````
