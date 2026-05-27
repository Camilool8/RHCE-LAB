## Task 16 — Logical volume in VG `research`

> Create a 1200 MiB ext4 logical volume named `data` in VG `research`.
> If 1200 MiB doesn't fit, print an error message and fall back to
> 800 MiB. If the VG doesn't exist, print an error. Don't mount it.

### What this teaches

- `block: / rescue: / always:` — the robust way to express "try X, if it
  fails fall back to Y" in Ansible. The `rescue:` only runs when the
  `block:` raises, so you don't have to predict failure conditions up
  front. `always:` runs whether `block:` or `rescue:` ran.
- `ansible_facts['lvm']` (gathered automatically when `lvm2` is installed)
  exposes the current VG / LV layout. Read it instead of shelling out
  to `vgs` / `lvs`.
- The `community.general.lvol` and `community.general.filesystem`
  modules are idempotent in their own right, so re-running the playbook
  doesn't grow / reformat the LV.

### Prerequisite: install the collection

```bash
ansible-galaxy collection install community.general -p ./mycollection/
```

Already wired into `ansible.cfg` via `collections_path = ./mycollection`
(task 1).

### `lvm.yml`

```yaml
- name: Create the research/data logical volume
  hosts: all
  become: true

  tasks:
    - name: Fail loudly if VG 'research' does not exist
      ansible.builtin.fail:
        msg: volume group does not exist
      when: "'research' not in ansible_facts['lvm']['vgs'] | default({})"

    - name: Create LV with the requested size, fall back if it doesn't fit
      block:
        - name: Try 1200 MiB
          community.general.lvol:
            vg: research
            lv: data
            size: 1200m
            state: present
      rescue:
        - name: Tell the user we're falling back
          ansible.builtin.debug:
            msg: could not create logical volume of that size
        - name: Fall back to 800 MiB
          community.general.lvol:
            vg: research
            lv: data
            size: 800m
            state: present

    - name: Format the LV as ext4
      community.general.filesystem:
        fstype: ext4
        dev: /dev/research/data
```

### Run

```bash
ansible-playbook lvm.yml
# or, with the exam runner:
ansible-navigator run lvm.yml --mode stdout
```

### Verify

```bash
ansible all -b -a 'lvs research/data'
ansible all -b -a 'blkid /dev/research/data'
# fstab should NOT have an entry for this LV, and findmnt must come up empty:
ansible all -b -a 'findmnt /dev/research/data || echo unmounted'
```

### Best-practice notes

- **`ansible_facts['lvm']['vgs']`** instead of `ansible_lvm['vgs']` — the
  bare-name form was deprecated in ansible-core 2.10; future-proof
  code uses the `ansible_facts.*` namespace.
- **FQCN modules** (`community.general.lvol`, not `lvol`) — required
  for ansible-navigator EE images, recommended for everything.
- **No `when:` inside `block:`** — the block-level fail-fast on the VG
  check makes the rest of the play unconditional and easier to read.
- The reference lab sizes the `research` VG to **1 GiB** specifically
  so the 1200 MiB request fails and the `rescue:` branch fires every
  time. That's how you know the rescue logic actually works — not just
  that it parses.
