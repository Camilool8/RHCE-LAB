# Task 13 — Rekey an Ansible Vault

Change the encryption password on the vault file created in Task 9.

**Vault file:** `/home/student/ansible/vault.yml`

## Requirements

### a) Source vault file

Use the `vault.yml` file created in the previous task. It is currently encrypted with the password `rh294lab`.

### b) New vault password

| Setting | Value |
|---------|-------|
| New encryption password | `ansible` |

### c) Vault state after rekeying

The vault file must remain **encrypted** after the operation — only the password changes. The variable names and values inside the vault must be unchanged.
