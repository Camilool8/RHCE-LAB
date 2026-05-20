# Snapshot and revert to a clean baseline

Take a snapshot after the first successful `vagrant up`. Revert to it whenever
a practice session leaves the lab in a state you do not want to keep.

The exact command depends on your provider.

## Take a `clean` snapshot of every VM

### VMware Fusion (macOS)

```bash
for m in repo control node1 node2 node3 node4 node5; do
  vmx=$(find .vagrant/machines/$m -name '*.vmx' | head -1)
  /Applications/VMware\ Fusion.app/Contents/Public/vmrun snapshot "$vmx" clean
done
```

### VirtualBox

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  VBoxManage snapshot "$vm" take clean
done
```

### libvirt

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  sudo virsh snapshot-create-as "$vm" clean
done
```

### Parallels

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  prlctl snapshot "$vm" -n clean
done
```

## Revert every VM to `clean`

### VMware Fusion

```bash
for m in repo control node1 node2 node3 node4 node5; do
  vmx=$(find .vagrant/machines/$m -name '*.vmx' | head -1)
  /Applications/VMware\ Fusion.app/Contents/Public/vmrun revertToSnapshot "$vmx" clean
  /Applications/VMware\ Fusion.app/Contents/Public/vmrun start "$vmx" nogui
done
```

### VirtualBox

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  VBoxManage snapshot "$vm" restore clean
done
vagrant up
```

### libvirt

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  sudo virsh snapshot-revert "$vm" clean --running
done
```

### Parallels

```bash
for vm in rhce-repo-server rhce-ansible-control rhce-node1 rhce-node2 \
          rhce-node3 rhce-node4 rhce-node5; do
  snap_id=$(prlctl snapshot-list "$vm" | awk '/clean/{print $1; exit}')
  prlctl snapshot-switch "$vm" -i "$snap_id"
done
```

## Revert a single VM

Replace `node1` with the VM name in the loops above and drop the `for`/`done`.

## List snapshots

```bash
# VMware Fusion
vmrun listSnapshots /path/to/<vm>.vmx

# VirtualBox
VBoxManage snapshot rhce-node1 list

# libvirt
sudo virsh snapshot-list rhce-node1

# Parallels
prlctl snapshot-list rhce-node1
```
