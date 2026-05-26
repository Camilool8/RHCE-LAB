# Task 3 — Install Packages

Create a playbook that installs packages on the appropriate host groups.

**Playbook path:** `/home/student/ansible/packages.yml`

## Requirements

### a) Install `php` and `mariadb`

- Target hosts: `dev`, `test`, and `prod` host groups.
- Both packages must be installed on every host in those groups.

### b) Install the RPM Development Tools package group

- Target hosts: `dev` host group **only**.
- Use the `@RPM Development Tools` package group syntax.

### c) Update all packages to the latest version

- Target hosts: `dev` host group **only**.
- All installed packages must be updated.
