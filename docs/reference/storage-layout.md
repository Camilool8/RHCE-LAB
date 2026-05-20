# Storage layout

Each managed node (`node1` … `node5`) has three disks: the OS root and two
extra disks. The extra disks' **device paths differ by provider**, and
their **sizes are intentionally asymmetric** so that one task's rescue
path is always exercised.

## Per-provider device names

| Provider         | OS root        | Extra disk 1 (task 17 — raw partition) | Extra disk 2 (task 16 — VG `research`) |
| ---------------- | -------------- | -------------------------------------- | -------------------------------------- |
| `virtualbox`     | `/dev/sda`     | `/dev/sdb`                             | `/dev/sdc`                             |
| `parallels`      | `/dev/sda`     | `/dev/sdb`                             | `/dev/sdc`                             |
| `libvirt`        | `/dev/vda`     | `/dev/vdb`                             | `/dev/vdc`                             |
| `vmware_desktop` | `/dev/nvme0n1` | `/dev/nvme0n2`                         | `/dev/nvme0n3`                         |

The lab does **not** rely on these names — both tasks and reference
solutions discover the disk at runtime. The table is here for debugging.

## Extra-disk size (intentionally asymmetric)

| Disk          | Default size  | Why                                                            |
| ------------- | ------------- | -------------------------------------------------------------- |
| Extra disk 1  | **2 GiB**     | task 17's 1200 MiB primary partition always fits — rescue path is a safety net |
| Extra disk 2  | **1 GiB**     | sized so task 16's 1200 MiB LV **doesn't fit** — rescue path falls back to 800 MiB every run, so the student knows it actually works |

Tune in [`config.yaml`](config-yaml.md):

```yaml
vms:
  nodes:
    extra_disks:
      - size: 2     # task 17 raw disk
      - size: 1     # task 16 VG (intentionally tight)
```

## Pre-built `research` volume group

The second extra disk is pre-formatted into a physical volume and added
to the `research` volume group during provisioning. Verify on a node:

```bash
vagrant ssh node1 -c "sudo vgs --noheadings -o vg_name,vg_size research"
# research <1.00g
```

This satisfies task 16's prerequisite (the task creates a logical volume
*inside* the existing `research` VG).

## First extra disk

Left raw and unpartitioned. Task 17 creates a partition on it. The
**task and reference solution both discover the disk at runtime** —
`/dev/sdb` is no longer hard-coded anywhere in the lab content.

## Writing playbooks that work across providers

The canonical pattern, used by `lab/solutions/answer-17.md`:

```yaml
- name: Pick the first unpartitioned non-root data disk
  ansible.builtin.set_fact:
    data_disk: >-
      {{ (ansible_facts.devices
          | dict2items
          | rejectattr('value.partitions', 'truthy')
          | rejectattr('key', 'match', '^(sda|vda|nvme0n1|sr|loop|fd|dm-).*')
          | rejectattr('value.size', 'equalto', '0.00 B')
          | map(attribute='key')
          | list
          | first) | default('') }}

- name: Fail clearly when no raw disk is attached
  ansible.builtin.fail:
    msg: this disk does not exist.
  when: data_disk == ''
```

Notes:

- NVMe partitions are `<disk>p1`, not `<disk>1`. Derive the partition
  path with a small conditional:

  ```jinja
  {{ '/dev/' + data_disk + ('p1' if data_disk.startswith('nvme') else '1') }}
  ```

- The `rejectattr('key', 'match', '^(sr|loop|fd|dm-).*')` clause is a
  conservative filter. Adjust if your hypervisor surfaces other virtual
  block devices (e.g. `zd*` on ZFS).

The lab's provisioner uses a simpler version of the same idea for the
`research` VG — it checks `/dev/sdc`, `/dev/vdc`, and `/dev/nvme0n3` in
order and uses whichever exists.

## Related

- [Topology](topology.md) — per-VM specs.
- [Tasks reference](tasks.md) — task 16 and task 17 details.
- [`lab/solutions/answer-17.md`](../../lab/solutions/answer-17.md) — the
  full discovery pattern in context.
