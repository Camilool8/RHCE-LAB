# Task 14 — Create User Accounts

Create a user variable file and a playbook that provisions users on the correct managed nodes using passwords from the Ansible vault.

**Variable file path:** `/home/student/ansible/user_list.yml`

**Playbook path:** `/home/student/ansible/create_user.yml`

## Requirements

### a) Create the variable file

Create `/home/student/ansible/user_list.yml` with the following content:

```yaml
users:
  - name: adam
    job: developer
    uid: 3000
  - name: gabriel
    job: manager
    uid: 3001
  - name: lucifer
    job: developer
    uid: 3002
```

### b) Developer accounts

Users whose `job` is `developer` must be created on managed nodes in the **`dev`** and **`test`** host groups with the following settings:

- Password sourced from the `dev_pass` vault variable.
- Member of the supplementary group **`devops`**.

### c) Manager accounts

Users whose `job` is `manager` must be created on managed nodes in the **`prod`** host group with the following settings:

- Password sourced from the `mgr_pass` vault variable.
- Member of the supplementary group **`opsmgr`**.

### d) Password hashing

All passwords must be hashed using the **SHA-512** format.

### e) Vault password file

The playbook must work when run with the vault password file created in Task 9:

```bash
ansible-playbook create_user.yml --vault-password-file password.txt
```
