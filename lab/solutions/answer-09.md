## Task 9 — Create an Ansible Vault to store user passwords

### What this teaches

- **`ansible-vault create`** — the canonical entry point. The opened
  editor lets you type plain YAML; on save, Vault encrypts and writes
  the file.
- **`--vault-password-file=<file>`** — non-interactive password input.
  The lab keeps the password in `./password.txt` (mode 0600) so
  playbooks can decrypt automatically — task 1's `ansible.cfg`
  references it via `vault_password_file = ./password.txt`.
- **What's inside the vault is just YAML**: the encryption is on the
  whole-file level. `ansible-vault edit` opens the decrypted YAML in
  your editor; saving re-encrypts.

### Create the password file

```bash
echo 'rh294lab' > password.txt
chmod 600 password.txt
```

`chmod 600` matters: a vault password file world-readable in a shared
filesystem nullifies the encryption.

### Create the vault

```bash
ansible-vault create vault.yml --vault-password-file=./password.txt
```

Your `$EDITOR` opens with an empty buffer. Type:

```yaml
---
dev_pass: redhat
mgr_pass: linux
```

Save and quit. The on-disk file now starts with `$ANSIBLE_VAULT;1.1;AES256`.

### Verify

```bash
ansible-vault view vault.yml --vault-password-file=./password.txt
# dev_pass: redhat
# mgr_pass: linux

head -1 vault.yml
# $ANSIBLE_VAULT;1.1;AES256
```

### Best-practice notes

- **Never edit `vault.yml` with `vi`** directly — that breaks the
  encryption header. Use `ansible-vault edit` (which manages the
  decrypt → edit → re-encrypt cycle for you).
- **One vault file per "secret domain"** is overkill for the exam but
  the right pattern in real life: `database.yml`, `aws.yml`, `users.yml`,
  each with its own password file. Otherwise a compromised password
  leaks everything.
- **`vault_password_file` in `ansible.cfg`** (set by task 1) means
  every `ansible-playbook` invocation in this directory auto-decrypts.
  In CI, point that variable at a file populated from a secret manager
  at job start.
- **You can also use `ansible-vault encrypt_string`** to embed a single
  encrypted variable inline in a regular YAML file. Useful when only
  one or two values are secret; here we want a dedicated vault so
  task 13 (rekey) is self-contained.
