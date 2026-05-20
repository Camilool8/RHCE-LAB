## Task 7 — Apply the downloaded `squid` role to the balancers group

### What this teaches

- **Consuming a Galaxy-installed role.** Once task 6 has put the role
  under `./roles/squid/`, the play just lists it under `roles:` — no
  extra search-path tweaking thanks to `roles_path = ./roles` in
  `ansible.cfg`.
- **Targeting a single group.** `hosts: balancers` is enough; no
  `when:` is needed because the play itself is scoped.

### `squid.yml`

```yaml
- name: Deploy Squid on the balancers group
  hosts: balancers
  become: true

  roles:
    - role: squid
```

### Run

```bash
ansible-playbook squid.yml
```

### Verify

```bash
ansible balancers -b -a 'systemctl is-active squid'
ansible balancers -b -a 'systemctl is-enabled squid'
ansible balancers -b -m shell -a 'ss -ltnp | grep -E ":3128|squid"'
```

### Best-practice notes

- **`hosts: balancers`** is correct even though the group has only
  `node5`. Don't hard-code `hosts: node5` — the moment a second load
  balancer joins the inventory the play stops scaling.
- **No `tags:` here.** Tags are useful when a play has 30 tasks and you
  want to run a subset; here the play is one role-include, so tags add
  noise.
- **Service binding port.** `squid` listens on 3128 by default. If you
  ever need to change that, the role exposes a `squid_http_port`
  variable; set it under `vars:` on the play, not by editing the role.
