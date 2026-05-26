# Snapshot and revert to a clean baseline

Take a snapshot **after the first successful `vagrant up`** and before any
practice work. The first run mirrors ~18 GB of packages onto the repo VM;
a snapshot captures that state so a reset is seconds, not minutes.

Revert to the snapshot whenever a practice session leaves the lab in a
state you do not want to keep.

The exact command depends on your provider.

---

## Take a `clean` snapshot of every VM

### VMware Fusion (macOS)

**Loop (bash):**

```bash
for m in repo control node1 node2 node3 node4 node5; do
  vmx=$(find .vagrant/machines/$m -name '*.vmx' | head -1)
  /Applications/VMware\ Fusion.app/Contents/Public/vmrun snapshot "$vmx" clean
done
```

**Standalone (bash):**

```bash
vmrun snapshot "$(find .vagrant/machines/repo     -name '*.vmx' | head -1)" clean
vmrun snapshot "$(find .vagrant/machines/control  -name '*.vmx' | head -1)" clean
vmrun snapshot "$(find .vagrant/machines/node1    -name '*.vmx' | head -1)" clean
vmrun snapshot "$(find .vagrant/machines/node2    -name '*.vmx' | head -1)" clean
vmrun snapshot "$(find .vagrant/machines/node3    -name '*.vmx' | head -1)" clean
vmrun snapshot "$(find .vagrant/machines/node4    -name '*.vmx' | head -1)" clean
vmrun snapshot "$(find .vagrant/machines/node5    -name '*.vmx' | head -1)" clean
```

---

### VirtualBox — macOS / Linux (bash)

**Loop:**

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  VBoxManage snapshot "$vm" take clean
done
```

**Standalone:**

```bash
VBoxManage snapshot rhce-repo-server    take clean
VBoxManage snapshot rhce-ansible-control take clean
VBoxManage snapshot rhce-node1          take clean
VBoxManage snapshot rhce-node2          take clean
VBoxManage snapshot rhce-node3          take clean
VBoxManage snapshot rhce-node4          take clean
VBoxManage snapshot rhce-node5          take clean
```

---

### VirtualBox — Windows (PowerShell)

**Loop:**

```powershell
foreach ($vm in @('rhce-repo-server','rhce-ansible-control',
                  'rhce-node1','rhce-node2','rhce-node3',
                  'rhce-node4','rhce-node5')) {
    VBoxManage snapshot $vm take clean
}
```

**Standalone:**

```powershell
VBoxManage snapshot rhce-repo-server     take clean
VBoxManage snapshot rhce-ansible-control take clean
VBoxManage snapshot rhce-node1           take clean
VBoxManage snapshot rhce-node2           take clean
VBoxManage snapshot rhce-node3           take clean
VBoxManage snapshot rhce-node4           take clean
VBoxManage snapshot rhce-node5           take clean
```

---

### libvirt (Linux)

**Loop:**

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  sudo virsh snapshot-create-as "$vm" clean
done
```

**Standalone:**

```bash
sudo virsh snapshot-create-as rhce-repo-server    clean
sudo virsh snapshot-create-as rhce-ansible-control clean
sudo virsh snapshot-create-as rhce-node1          clean
sudo virsh snapshot-create-as rhce-node2          clean
sudo virsh snapshot-create-as rhce-node3          clean
sudo virsh snapshot-create-as rhce-node4          clean
sudo virsh snapshot-create-as rhce-node5          clean
```

---

### Parallels (macOS)

**Loop:**

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  prlctl snapshot "$vm" -n clean
done
```

**Standalone:**

```bash
prlctl snapshot rhce-repo-server    -n clean
prlctl snapshot rhce-ansible-control -n clean
prlctl snapshot rhce-node1          -n clean
prlctl snapshot rhce-node2          -n clean
prlctl snapshot rhce-node3          -n clean
prlctl snapshot rhce-node4          -n clean
prlctl snapshot rhce-node5          -n clean
```

---

## Revert every VM to `clean`

### VMware Fusion (macOS)

**Loop (bash):**

```bash
for m in repo control node1 node2 node3 node4 node5; do
  vmx=$(find .vagrant/machines/$m -name '*.vmx' | head -1)
  /Applications/VMware\ Fusion.app/Contents/Public/vmrun revertToSnapshot "$vmx" clean
  /Applications/VMware\ Fusion.app/Contents/Public/vmrun start "$vmx" nogui
done
```

**Standalone (bash):**

```bash
VMRUN=/Applications/VMware\ Fusion.app/Contents/Public/vmrun
VMX_REPO=$(find .vagrant/machines/repo    -name '*.vmx' | head -1)
VMX_CTRL=$(find .vagrant/machines/control -name '*.vmx' | head -1)
VMX_N1=$(find .vagrant/machines/node1 -name '*.vmx' | head -1)
VMX_N2=$(find .vagrant/machines/node2 -name '*.vmx' | head -1)
VMX_N3=$(find .vagrant/machines/node3 -name '*.vmx' | head -1)
VMX_N4=$(find .vagrant/machines/node4 -name '*.vmx' | head -1)
VMX_N5=$(find .vagrant/machines/node5 -name '*.vmx' | head -1)

"$VMRUN" revertToSnapshot "$VMX_REPO" clean && "$VMRUN" start "$VMX_REPO" nogui
"$VMRUN" revertToSnapshot "$VMX_CTRL" clean && "$VMRUN" start "$VMX_CTRL" nogui
"$VMRUN" revertToSnapshot "$VMX_N1"   clean && "$VMRUN" start "$VMX_N1"   nogui
"$VMRUN" revertToSnapshot "$VMX_N2"   clean && "$VMRUN" start "$VMX_N2"   nogui
"$VMRUN" revertToSnapshot "$VMX_N3"   clean && "$VMRUN" start "$VMX_N3"   nogui
"$VMRUN" revertToSnapshot "$VMX_N4"   clean && "$VMRUN" start "$VMX_N4"   nogui
"$VMRUN" revertToSnapshot "$VMX_N5"   clean && "$VMRUN" start "$VMX_N5"   nogui
```

---

### VirtualBox — macOS / Linux (bash)

**Loop:**

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  VBoxManage snapshot "$vm" restore clean
done
vagrant up
```

**Standalone:**

```bash
VBoxManage snapshot rhce-repo-server    restore clean
VBoxManage snapshot rhce-ansible-control restore clean
VBoxManage snapshot rhce-node1          restore clean
VBoxManage snapshot rhce-node2          restore clean
VBoxManage snapshot rhce-node3          restore clean
VBoxManage snapshot rhce-node4          restore clean
VBoxManage snapshot rhce-node5          restore clean
vagrant up
```

---

### VirtualBox — Windows (PowerShell)

**Loop:**

```powershell
foreach ($vm in @('rhce-repo-server','rhce-ansible-control',
                  'rhce-node1','rhce-node2','rhce-node3',
                  'rhce-node4','rhce-node5')) {
    VBoxManage snapshot $vm restore clean
}
vagrant up
```

**Standalone:**

```powershell
VBoxManage snapshot rhce-repo-server     restore clean
VBoxManage snapshot rhce-ansible-control restore clean
VBoxManage snapshot rhce-node1           restore clean
VBoxManage snapshot rhce-node2           restore clean
VBoxManage snapshot rhce-node3           restore clean
VBoxManage snapshot rhce-node4           restore clean
VBoxManage snapshot rhce-node5           restore clean
vagrant up
```

---

### libvirt (Linux)

**Loop:**

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  sudo virsh snapshot-revert "$vm" clean --running
done
```

**Standalone:**

```bash
sudo virsh snapshot-revert rhce-repo-server    clean --running
sudo virsh snapshot-revert rhce-ansible-control clean --running
sudo virsh snapshot-revert rhce-node1          clean --running
sudo virsh snapshot-revert rhce-node2          clean --running
sudo virsh snapshot-revert rhce-node3          clean --running
sudo virsh snapshot-revert rhce-node4          clean --running
sudo virsh snapshot-revert rhce-node5          clean --running
```

---

### Parallels (macOS)

**Loop:**

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  snap_id=$(prlctl snapshot-list "$vm" | awk '/clean/{print $1; exit}')
  prlctl snapshot-switch "$vm" -i "$snap_id"
done
```

**Standalone:**

```bash
prlctl snapshot-switch rhce-repo-server    -i "$(prlctl snapshot-list rhce-repo-server    | awk '/clean/{print $1; exit}')"
prlctl snapshot-switch rhce-ansible-control -i "$(prlctl snapshot-list rhce-ansible-control | awk '/clean/{print $1; exit}')"
prlctl snapshot-switch rhce-node1          -i "$(prlctl snapshot-list rhce-node1          | awk '/clean/{print $1; exit}')"
prlctl snapshot-switch rhce-node2          -i "$(prlctl snapshot-list rhce-node2          | awk '/clean/{print $1; exit}')"
prlctl snapshot-switch rhce-node3          -i "$(prlctl snapshot-list rhce-node3          | awk '/clean/{print $1; exit}')"
prlctl snapshot-switch rhce-node4          -i "$(prlctl snapshot-list rhce-node4          | awk '/clean/{print $1; exit}')"
prlctl snapshot-switch rhce-node5          -i "$(prlctl snapshot-list rhce-node5          | awk '/clean/{print $1; exit}')"
```

---

## Revert a single VM

Pick the block for your provider, drop the loop, and replace the VM name.

**Example — VirtualBox (bash):**

```bash
VBoxManage snapshot rhce-node1 restore clean
vagrant up node1
```

**Example — VirtualBox (PowerShell):**

```powershell
VBoxManage snapshot rhce-node1 restore clean
vagrant up node1
```

---

## List snapshots

```bash
# VMware Fusion
vmrun listSnapshots /path/to/<vm>.vmx

# VirtualBox (bash or PowerShell)
VBoxManage snapshot rhce-node1 list

# libvirt
sudo virsh snapshot-list rhce-node1

# Parallels
prlctl snapshot-list rhce-node1
```
