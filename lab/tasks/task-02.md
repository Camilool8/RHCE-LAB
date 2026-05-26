# Task 2 — Configure YUM Repositories

Create a playbook that configures the required YUM repositories on all managed nodes.

**Playbook path:** `/home/student/ansible/yum-repo.yml`

## Requirements

Create **two** YUM repositories on every managed node using the details below.

### Repository 1 — BaseOS

| Parameter | Value |
|-----------|-------|
| `name` | `BaseOS` |
| `baseurl` | `file:///mnt/BaseOS/` |
| `description` | `Base OS Repo` |
| `gpgcheck` | `yes` |
| `enabled` | `no` |
| `gpgkey` | `file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9` |

### Repository 2 — AppStream

| Parameter | Value |
|-----------|-------|
| `name` | `AppStream` |
| `baseurl` | `file:///mnt/AppStream/` |
| `description` | `AppStream Repo` |
| `gpgcheck` | `yes` |
| `enabled` | `no` |
| `gpgkey` | `file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9` |
