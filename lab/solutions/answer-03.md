## Task 3 — Package install + group + full update, scoped by host group

### What this teaches

- **The difference between `state: present` and `state: latest`.**
  `present` is idempotent (a second run is a no-op when the package is
  already installed); `latest` checks for upgrades on every run, so it's
  inherently non-idempotent when an update is available. Use the right
  one for each ask.
- **Scoping by host group** without a giant `when:` chain — `group_names`
  is the per-host list of every group the host belongs to.
- **The `@<group>` syntax** for `ansible.builtin.dnf` is how you install
  package *groups* (comps.xml entries), as opposed to single RPMs.

### `packages.yml`

```yaml
- name: Install packages by host group
  hosts: all
  become: true

  tasks:
    - name: php and mariadb on dev, test, and prod
      ansible.builtin.dnf:
        name:
          - php
          - mariadb
        state: present
      when: group_names | intersect(['dev', 'test', 'prod']) | length > 0

    - name: RPM Development Tools group on dev
      ansible.builtin.dnf:
        name: '@RPM Development Tools'
        state: present
      when: "'dev' in group_names"

    - name: Update all packages on dev
      ansible.builtin.dnf:
        name: '*'
        state: latest
      when: "'dev' in group_names"
```

### Run

```bash
ansible-playbook packages.yml
```

### Verify

```bash
ansible dev,test,prod -b -m shell -a 'rpm -q php mariadb'
ansible dev            -b -m shell -a 'dnf group list --installed | grep -i "RPM Development Tools"'
ansible balancers      -b -m shell -a 'rpm -q php  || echo php-not-installed'
```

### Best-practice notes

- **`state: present`** for the named packages — second run reports
  `changed=0`. The original reference used `state: latest` and got
  flagged as non-idempotent.
- **`state: latest` on the wildcard task is the one place it's correct**
  because the task literally says "update all packages." That one is
  non-idempotent by definition (a new errata between runs is a real
  upgrade). The verifier knows.
- **`group_names | intersect([...])`** scales — adding `staging` to the
  list is a one-line edit. The original `inventory_hostname in
  groups['dev'] or in groups['test'] or ...` chain doesn't.
- **YAML list under `name:`** instead of a `loop:` — `dnf` natively
  accepts multiple packages in one transaction, which is faster and
  resolves dependencies together.
