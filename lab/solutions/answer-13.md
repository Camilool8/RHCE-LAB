## Task 13 — Rekey the vault to a new password

### What this teaches

- **`ansible-vault rekey`** changes the password on an existing
  encrypted file without exposing the plaintext. Vault decrypts with
  the old password in memory and re-encrypts with the new one.
- **Non-interactive rekey** with `--vault-password-file` (old) and
  `--new-vault-password-file` (new) — automatable, no prompts.
- **`ansible.cfg`'s `vault_password_file`** then needs to point at the
  *new* file. The lab keeps the same `password.txt` path and just
  overwrites its contents, so no cfg edit is needed.

### Two ways to do it

**A — non-interactive (recommended, scriptable):**

```bash
# Capture the new password in a temp file
echo 'ansible' > /tmp/new-vault-pw

# Rekey
ansible-vault rekey vault.yml \
  --vault-password-file=./password.txt \
  --new-vault-password-file=/tmp/new-vault-pw

# Replace password.txt with the new password
mv /tmp/new-vault-pw password.txt
chmod 600 password.txt
```

**B — interactive (what the exam might walk you through):**

```bash
ansible-vault rekey vault.yml
# Vault password:           (type rh294lab)
# New Vault password:       (type ansible)
# Confirm New Vault password: (type ansible)

echo 'ansible' > password.txt
chmod 600 password.txt
```

### Verify

```bash
# New password works
ansible-vault view vault.yml --vault-password-file=./password.txt
# dev_pass: redhat
# mgr_pass: linux

# Old password rejected
echo 'rh294lab' > /tmp/old.txt
ansible-vault view vault.yml --vault-password-file=/tmp/old.txt
# ERROR! Decryption failed
rm /tmp/old.txt
```

### Best-practice notes

- **Update `password.txt` AFTER the rekey succeeds**, not before. If
  the rekey fails (typo, locked file), you still have the working
  password.
- **`chmod 600 password.txt`** — repeat every time you rewrite the
  file. The previous mode is preserved by `mv` but not by `>`.
- **The vault header doesn't change** (still
  `$ANSIBLE_VAULT;1.1;AES256`) — the salt and key derivation are
  embedded in the body. `head -1 vault.yml` looks identical before and
  after.
- **Don't commit `password.txt`** — confirm `.gitignore` excludes it
  before adding the rekey step to a real repo.
