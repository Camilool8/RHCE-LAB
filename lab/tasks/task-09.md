# Task 9 — Create an Ansible Vault

Create an encrypted Ansible vault file to securely store user passwords.

**Vault file path:** `/home/student/ansible/vault.yml`

**Vault password file:** `/home/student/ansible/password.txt`

## Requirements

### a) Vault file name

The vault file must be named `vault.yml` and stored at the path above.

### b) Variables

The vault must contain the following two variables:

| Variable | Value |
|----------|-------|
| `dev_pass` | `redhat` |
| `mgr_pass` | `linux` |

### c) Vault password

| Setting | Value |
|---------|-------|
| Encryption/decryption password | `rh294lab` |

### d) Password file

Store the vault password in a plain-text file at `/home/student/ansible/password.txt` so that playbooks can reference it with `--vault-password-file`.

> **Security note:** Do not commit `password.txt` or `vault.yml` (unencrypted) to version control.
