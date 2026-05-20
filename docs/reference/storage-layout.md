# Storage layout

Each managed node (`node1` … `node5`) has three disks: the OS root and two
extra disks. The extra disks' **device paths differ by provider**.

## Per-provider device names

| Provider         | OS root        | Extra disk 1 (task 17) | Extra disk 2 (task 16 — VG `research`) |
| ---------------- | -------------- | ---------------------- | -------------------------------------- |
| `virtualbox`     | `/dev/sda`     | `/dev/sdb`             | `/dev/sdc`                             |
| `parallels`      | `/dev/sda`     | `/dev/sdb`             | `/dev/sdc`                             |
| `libvirt`        | `/dev/vda`     | `/dev/vdb`             | `/dev/vdc`                             |
| `vmware_desktop` | `/dev/nvme0n1` | `/dev/nvme0n2`         | `/dev/nvme0n3`                         |

## Extra-disk size

Both extras default to **2 GB**. Tune in [`config.yaml`](config-yaml.md):

```yaml
vms:
  nodes:
    extra_disks:
      - size: 2 # extra disk 1
      - size: 2 # extra disk 2
```

## Pre-built `research` volume group

The second extra disk is pre-formatted into a physical volume and added to
the `research` volume group during provisioning. Verify on a node:

```bash
vagrant ssh node1 -c "sudo vgs --noheadings -o vg_name,vg_size research"
# research <2.00g
```

This satisfies task 16's prerequisite (the task creates a logical volume
inside the existing `research` VG).

## First extra disk

Left raw and unpartitioned. Task 17 expects to create a partition on it.

## Writing playbooks that work across providers

Use `ansible_facts['devices']` or `lsblk -d -e1,7,11 -ndo NAME` to discover
the device names at runtime instead of hard-coding `/dev/sdb`:

```yaml
- name: Find the first raw disk
  ansible.builtin.set_fact:
    raw_disk: "/dev/{{ ansible_facts.devices
      | dict2items
      | rejectattr('value.partitions', 'truthy')
      | rejectattr('key', 'match', '^(sda|vda|nvme0n1)$')
      | map(attribute='key')
      | first }}"
```

The lab's provisioner does this for the `research` VG — it checks
`/dev/sdc`, `/dev/vdc`, and `/dev/nvme0n3` in order and uses whichever exists.

## Related

- [Topology](topology.md) — per-VM specs.
- [Tasks reference](tasks.md) — task 16 and task 17 details.
