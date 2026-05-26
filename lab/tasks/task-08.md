# Task 8 — Configure a Web Test Directory

Create a playbook that sets up a shared web test directory with the correct permissions and a symbolic link.

**Playbook path:** `/home/student/ansible/test.yml`

## Requirements

### a) Target hosts

The playbook must run on managed nodes in the **`test`** host group.

### b) Create the `/webtest` directory

- Group ownership must be set to the `webtest` group.
- Standard permissions:
  - Owner: `rwx`
  - Group: `rwx`
  - Others: `r-x`
- Special permission: **Set Group ID (SGID)** bit must be applied.

### c) Create a symbolic link

Create a symbolic link at `/var/www/html/webtest` that points to `/webtest`.

### d) Create the index file

Create the file `/webtest/index.html` containing exactly the following single line of text:

```
Testing
```
