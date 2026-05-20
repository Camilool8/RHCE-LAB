## Task 1 — Inventory and `ansible.cfg`

### What this teaches

- The static-INI inventory format and group hierarchy
  (`[webservers:children]` makes `webservers` a parent of `prod`).
- The exact `ansible.cfg` knobs that make `ansible all -m ping`
  Just Work from `/home/student/ansible/` with no extra flags — the
  EX294 grader assumes this.
- Pre-wiring `vault_password_file` so playbooks that read encrypted
  variables (task 14) need no `--vault-password-file` argument.

### `inventory`

```ini
[dev]
node1

[test]
node2

[prod]
node3
node4

[balancers]
node5

[webservers:children]
prod
```

### `ansible.cfg`

```ini
[defaults]
inventory            = ./inventory
roles_path           = ./roles
collections_path     = ./mycollection
remote_user          = student
private_key_file     = ~/.ssh/RH294-LAB
host_key_checking    = False
vault_password_file  = ./password.txt
nocows               = True
stdout_callback      = yaml
deprecation_warnings = False
retry_files_enabled  = False
forks                = 10
```

### Run

```bash
ansible all -m ping
ansible-inventory --graph
```

`ansible-inventory --graph` should print the group tree with `prod`
nested under `webservers`.

### Best-practice notes

- **`vault_password_file = ./password.txt`** turns
  `ansible-playbook create_user.yml` into a one-liner. Task 14's
  reference solution then doesn't need to pass `--vault-password-file`
  every time — the grader runs the same shorthand.
- **`stdout_callback = yaml`** makes module output human-readable
  during practice. Switch to `json` in CI.
- **`forks = 10`** parallelizes across the 5 managed nodes (default
  is 5 — fine, but 10 leaves headroom).
- The cfg lives at **`./ansible.cfg`** (current directory) so it only
  takes effect when running from `/home/student/ansible/`. That's
  intentional — a system-wide `/etc/ansible/ansible.cfg` would leak
  into unrelated work.
