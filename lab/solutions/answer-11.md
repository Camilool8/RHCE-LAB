## Task 11 — Per-host hardware report under `/root/hwreport.txt`

### What this teaches

- **`ansible_facts.*` for hardware introspection** — `memtotal_mb`,
  `bios_version`, `processor_count`, `architecture`. These are the
  canonical fact names; no `setup` invocation needed beyond default
  fact-gathering.
- **The `default('NONE', true)` filter** — `default('NONE')` falls back
  only when the value is *undefined*. The second `true` argument also
  makes it fall back on *empty* strings, which is what you get for
  `bios_version` on hypervisors that don't expose it (libvirt sometimes,
  parallels often). Without `true`, the template would render
  `BIOS_VERSION=` with no value.
- **Single-source-of-truth templating** — the same template produces a
  per-host file because the facts vary per-host.

### `hwreport.j2`

```jinja
INVENTORY_HOSTNAME={{ inventory_hostname }}
TOTAL_MEMORY_IN_MB={{ ansible_facts['memtotal_mb'] }}
BIOS_VERSION={{ ansible_facts['bios_version'] | default('NONE', true) }}
```

### `hwreport.yml`

```yaml
- name: Generate /root/hwreport.txt on every node
  hosts: all
  become: true

  tasks:
    - name: Render the hardware report
      ansible.builtin.template:
        src: hwreport.j2
        dest: /root/hwreport.txt
        owner: root
        group: root
        mode: '0644'
```

### Run

```bash
ansible-playbook hwreport.yml
# or, with the exam runner:
ansible-navigator run hwreport.yml --mode stdout
```

### Verify

```bash
ansible all -b -a 'cat /root/hwreport.txt'

# Expect on a libvirt host where BIOS is masked:
#   INVENTORY_HOSTNAME=node3
#   TOTAL_MEMORY_IN_MB=1280
#   BIOS_VERSION=NONE
```

### Best-practice notes

- **`inventory_hostname` (not `ansible_facts['hostname']`)** — the
  task asks for the *inventory* name, which is the name Ansible uses to
  reach the host. `ansible_facts['hostname']` is what the host reports
  for itself (could differ — e.g. an aliased inventory entry).
- **`default('NONE', true)`** with the second positional arg makes
  empty strings fall back too. Common gotcha on virtualized hardware.
- **No `vars:` and no per-host customization** — every node renders
  the same template against its own facts. Don't over-engineer this.
- **Quote the mode** (`'0644'`) — see the discussion in answer-08.
