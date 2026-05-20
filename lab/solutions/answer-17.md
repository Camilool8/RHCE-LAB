## Task 17 — Portable partition + mount on the raw data disk

> Create a 1200 MiB ext4 primary partition on the additional raw data
> disk of every managed node. Mount it at `/srv` on the prod group,
> persistently. Fall back to 800 MiB if 1200 doesn't fit. Error out if
> there's no raw disk.

### What this teaches

- **Device-name portability.** AlmaLinux 9 boots `/dev/sda` on
  VirtualBox/Parallels, `/dev/vda` on libvirt, `/dev/nvme0n1` on
  VMware. Real production playbooks behave the same way. Discover at
  runtime; never hard-code `/dev/sdb`.
- **Filtering `ansible_facts.devices`.** It's a dict keyed by short
  device name. Each entry exposes `partitions` (a dict — empty for a
  raw disk), `size` (a human string), `removable`, etc. The "first
  unused data disk" is the first entry whose `partitions` is empty and
  whose name isn't the root disk.
- **Persistent mount with `ansible.posix.mount`.** `state: mounted`
  writes `/etc/fstab` AND issues the mount; `state: present` writes
  fstab but does not mount. Use `mounted` whenever the task says
  "permanent" or "survives reboot".
- **`block / rescue`** for fall-back partition sizes.

### Prerequisites

```bash
ansible-galaxy collection install community.general -p ./mycollection/
ansible-galaxy collection install ansible.posix     -p ./mycollection/
```

### `partition.yml`

```yaml
- name: Create + mount the data partition portably
  hosts: all
  become: true

  tasks:
    # ---- 1. Discover the raw disk (no hard-coded /dev/sdb) ----------
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
        # Examples that match: vdb, sdb, nvme0n2.
        # Examples that don't:  vda (has partitions), sr0 (cdrom),
        #                       loop0 (loopback), dm-0 (LVM mapper).

    - name: Fail clearly when no raw disk is attached
      ansible.builtin.fail:
        msg: this disk does not exist.
      when: data_disk == ''

    - name: Expose convenient paths for downstream tasks
      ansible.builtin.set_fact:
        data_disk_path: "/dev/{{ data_disk }}"
        data_part_path: "/dev/{{ data_disk }}{{ '1' if not data_disk.startswith('nvme') else 'p1' }}"
        # NVMe partitions get a 'p' between the disk and the partition
        # number — /dev/nvme0n2p1, not /dev/nvme0n21.

    # ---- 2. Create the partition (1200 MiB, fall back to 800) -------
    - name: Create a 1200 MiB primary partition (fall back to 800)
      block:
        - name: Try 1200 MiB
          community.general.parted:
            device: "{{ data_disk_path }}"
            number: 1
            state: present
            part_end: 1200MiB
            fs_type: ext4
      rescue:
        - name: Announce the fallback
          ansible.builtin.debug:
            msg: Could not create partition of that size
        - name: Fall back to 800 MiB
          community.general.parted:
            device: "{{ data_disk_path }}"
            number: 1
            state: present
            part_end: 800MiB
            fs_type: ext4

    # ---- 3. Format as ext4 (idempotent — only writes if blank) ------
    - name: Format the partition as ext4
      community.general.filesystem:
        dev: "{{ data_part_path }}"
        fstype: ext4

    # ---- 4. Persistent mount at /srv, on prod nodes only ------------
    - name: Mount on /srv (prod only, persistent)
      ansible.posix.mount:
        path: /srv
        src: "{{ data_part_path }}"
        fstype: ext4
        state: mounted
      when: "'prod' in group_names"
```

### Run

```bash
ansible-playbook partition.yml
```

### Verify

```bash
# Partition + filesystem (works on every hypervisor — names differ)
ansible all  -b -m shell -a "lsblk -f | grep -E 'ext4|vdb|sdb|nvme0n2'"

# Prod nodes have /srv mounted from the new partition, with fstab persistence
ansible prod -b -a 'findmnt /srv'
ansible prod -b -a 'grep "/srv" /etc/fstab'

# Non-prod nodes have the partition but /srv is NOT mounted from it
ansible test,dev,balancers -b -m shell -a 'findmnt /srv || echo not-mounted'
```

### Best-practice notes

- **`group_names`** (a per-host list) instead of looking the host up in
  `groups['prod']`. Reads more naturally.
- **`fs_type: ext4` on the `parted` task** writes the GPT partition-type
  label; **`community.general.filesystem`** does the actual mkfs.
  Both — `parted` alone won't lay down a usable filesystem.
- **Set `data_part_path` once** as a fact instead of repeating
  `{{ data_disk_path }}1` everywhere — keeps NVMe-vs-SCSI naming logic
  in one place.
- **`state: mounted`** on `ansible.posix.mount` writes fstab AND
  performs the mount in a single idempotent task. Don't combine
  `state: present` with a separate `command: mount …`.
- This task is the lab's canonical example of "your playbook is
  expected to work across hypervisors." See
  [`docs/explanation/known-task-discrepancies.md`](../../docs/explanation/known-task-discrepancies.md)
  for the history.
