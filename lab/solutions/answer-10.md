## Task 10 — `hosts.j2` template + `/etc/myhosts` on dev

### What this teaches

- **`hostvars[h]`** lets a play running on host A read facts about
  host B. The classic use case is generating per-host config from
  fleet-wide knowledge — exactly this.
- **Iterating `groups['all']`** in Jinja2 — the same data
  `ansible-inventory --list` returns, but accessible at template time.
- **Fact gathering across the fleet.** For `hostvars[node].ansible_facts`
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
{{ '%-15s' % hostvars[h].ansible_facts.default_ipv4.address }} {{ hostvars[h].ansible_facts.fqdn }} {{ hostvars[h].ansible_facts.hostname }}
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
```

### Verify

```bash
ansible dev  -b -a 'cat /etc/myhosts'
ansible test -b -m shell -a 'test -f /etc/myhosts && echo PRESENT || echo absent'
# absent — only dev should have the file
```

### Best-practice notes

- **`hosts: all`** even though only dev writes the file — running on
  every host guarantees `hostvars[h].ansible_facts` is populated for
  every `h`. If the play ran only on dev, the inner facts wouldn't be
  collected for non-dev nodes.
- **`'dev' in group_names`** in the `when:` — same readability as
  `inventory_hostname in groups['dev']`, but doesn't depend on a
  separately-resolved `groups` lookup.
- **`| sort`** on the iteration — makes the output deterministic.
  Without it, group membership ordering can shuffle between runs and
  `ansible.builtin.template` reports `changed=1` for purely cosmetic
  reasons.
- **`'%-15s' % ip`** — left-pads the IP so the FQDNs line up. Matches
  the look of a real `/etc/hosts`.
