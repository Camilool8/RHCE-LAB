# Repository file tree

```
RHCE-LAB/
├── README.md                    # thin front door
├── Vagrantfile                  # provider auto-selection + VM definitions
├── config.yaml                  # lab configuration (see config-yaml.md)
├── .gitignore
│
├── files/                       # static assets uploaded to the VMs
│   ├── ansible.cfg              # reference ansible.cfg (not auto-installed)
│   ├── vimrc                    # editor config dropped to /home/student/.vimrc
│   └── keys/                    # RH294-LAB keypair, generated, gitignored
│
├── scripts/                     # provisioner scripts run by Vagrant
│   ├── common/
│   │   ├── base-setup.sh                # firewalld, NetworkManager, base packages
│   │   ├── configure-lab-network.sh     # nmcli — sets eth1 IP, zone=internal
│   │   └── create-users.sh              # student, redhat
│   ├── repo-server/
│   │   ├── setup-repos.sh               # httpd, BaseOS/AppStream repos
│   │   ├── setup-nfs.sh                 # NFS exports
│   │   └── setup-gpg.sh                 # publishes the AlmaLinux GPG key
│   ├── control/
│   │   └── setup-control.sh             # ansible-core, navigator, EE pull
│   └── node/
│       └── setup-node.sh                # python3, lvm2, RH294-LAB authorized_keys,
│                                        # NFS automount fstab, research VG
│
├── lab/                         # practice content (read-only at runtime)
│   ├── tasks/                   # task-01.md … task-18.md
│   └── solutions/               # answer-01.md … answer-18.md
│
├── disks/                       # per-node extra disk files, gitignored
│
├── .vagrant/                    # Vagrant state, gitignored
│
└── docs/                        # this documentation
    ├── README.md                # docs index
    ├── tutorial/
    ├── how-to/
    ├── reference/
    └── explanation/
```

## Per-directory purpose

### `scripts/common/`

Scripts that every VM runs in this order:

1. `base-setup.sh` — installs `firewalld`, `NetworkManager`, base utilities; binds the lab subnet to firewalld's `internal` zone.
2. `configure-lab-network.sh` — assigns the lab IP to `eth1` via NetworkManager keyfile, with `connection.zone=internal`.
3. `create-users.sh` — creates the `student` and `redhat` users.

### `scripts/repo-server/`

Run only on the `repo` VM, after the common scripts. Mirror the upstream
AlmaLinux BaseOS and AppStream into `/var/www/html/repo/` with
`dnf reposync` (the only step that needs internet — once complete the
rest of the lab is fully offline-capable), expose them via HTTP and NFS,
and publish the distribution GPG key. See
[`explanation/offline-mirror.md`](../explanation/offline-mirror.md).

### `scripts/control/`

Run only on the `control` VM. Installs `ansible-core`, builds/installs
`ansible-navigator`, populates `/etc/hosts`, pre-pulls the execution
environment image.

### `scripts/node/`

Run only on the managed nodes. Authorizes the `RH294-LAB` public key for
`student`, builds the `research` VG, sets up NFS automount.

### `files/`

Anything uploaded verbatim to a VM via Vagrant's `file` provisioner.

### `lab/`

The 18 EX294 practice tasks and their reference solutions. Read-only — do
not edit while practicing.

### `disks/`

Provider-specific extra-disk files (`.vdi`, `.vmdk`, `.qcow2`). Created on
demand, deleted by `vagrant destroy`. Always gitignored.

### `docs/`

The documentation you are reading.

### Internal directories

- `.vagrant/` — Vagrant's per-machine state. Gitignored.

## Related

- [`config.yaml`](config-yaml.md) — the one file you actually edit.
