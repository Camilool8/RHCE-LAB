## Task 10 — `hosts.j2` template + `/etc/myhosts` on dev

### What this teaches

- **`hostvars[h]`** lets a play running on host A read facts about
  host B. The classic use case is generating per-host config from
  fleet-wide knowledge — exactly this.
- **Iterating `groups['all']`** in Jinja2 — the same data
  `ansible-inventory --list` returns, but accessible at template time.
- **Fact gathering across the fleet.** For `hostvars[node]['ansible_facts']`
  to be populated, the play must `gather_facts: true` (default) on the
  hosts you iterate over — `hosts: all` handles that.
- **Per-host file output with a single play.** Running on `hosts: all`
  with a `when:` keeps the play targeted while still gathering every
  node's facts.

### `hosts.j2`

```jinja
127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
::1       localhost localhost.localdomain localhost6 localhost6.localdomain6
{% for h in groups['all'] | sort %}
{{ '%-15s' % hostvars[h]['ansible_eth1']['ipv4']['address'] }} {{ hostvars[h]['ansible_fqdn'] }} {{ hostvars[h]['ansible_hostname'] }}
{% endfor %}
```

### `gen_hosts.yml`

```yaml
- name: Generate /etc/myhosts on the dev group
  hosts: all
  become: true

  tasks:
    - name: Render the per-fleet hosts file (dev nodes only)
      ansible.builtin.template:
        src: hosts.j2
        dest: /etc/myhosts
        owner: root
        group: root
        mode: '0644'
      when: "'dev' in group_names"
```

### Run

```bash
ansible-playbook gen_hosts.yml
# or, with the exam runner:
ansible-navigator run gen_hosts.yml --mode stdout
```

### Verify

```bash
ansible dev  -b -a 'cat /etc/myhosts'
ansible test -b -m shell -a 'test -f /etc/myhosts && echo PRESENT || echo absent'
# absent — only dev should have the file
```

### Best-practice notes

- **`hosts: all`** even though only dev writes the file — running on
  every host guarantees `hostvars[h]['ansible_facts']` is populated for
  every `h`. If the play ran only on dev, the inner facts wouldn't be
  collected for non-dev nodes.
- **`'dev' in group_names`** in the `when:` — same readability as
  `inventory_hostname in groups['dev']`, but doesn't depend on a
  separately-resolved `groups` lookup.
- **`ansible_eth1` not `default_ipv4`** — this is a **lab-specific
  workaround, not a best practice**. On the real exam (and any
  single-NIC host) you would use `default_ipv4.address` and it would
  work correctly. In this lab every VirtualBox VM has two NICs: `eth0`
  (NAT, used by Vagrant for SSH) and `eth1` (the lab private network
  `192.168.56.0/24`). VirtualBox NAT gives *all* VMs the same IP on
  `eth0` (`10.0.2.15`), so `default_ipv4.address` resolves to the same
  address on every node and the generated file becomes useless. The fix
  is intentional: it forces you to navigate the `ansible_facts`
  hierarchy by interface name rather than relying on the convenient
  `default_ipv4` shortcut — giving you more hands-on practice with fact
  variables and nested dict access.
- **`hostvars[h]['ansible_eth1']` vs `hostvars[h]['ansible_facts']['ansible_eth1']`**
  — when accessing a *remote* host's facts via `hostvars`, Ansible
  injects facts at two places: directly at the top level of `hostvars[h]`
  (with the `ansible_` prefix, e.g. `hostvars[h]['ansible_eth1']`) and
  under `hostvars[h]['ansible_facts']` (without the prefix, e.g.
  `hostvars[h]['ansible_facts']['eth1']`). The `hostvars[h]['ansible_facts']['ansible_eth1']`
  path (prefix inside `ansible_facts`) does **not** exist and will
  error. Always use either `hostvars[h]['ansible_eth1']` or
  `hostvars[h]['ansible_facts']['eth1']`. You can confirm the available
  keys for any node with:
  ```bash
  ansible node1 -m setup -a 'filter=ansible_eth*'
  ansible node1 -m setup -a 'filter=ansible_interfaces'
  ```
- **`| sort`** on the iteration — makes the output deterministic.
  Without it, group membership ordering can shuffle between runs and
  `ansible.builtin.template` reports `changed=1` for purely cosmetic
  reasons.
- **`'%-15s' % ip`** — left-pads the IP so the FQDNs line up. Matches
  the look of a real `/etc/hosts`.
