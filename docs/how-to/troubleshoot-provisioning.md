# Troubleshoot a provisioner failure

Symptom: `vagrant up` exits with a non-zero status, a `WARN:` line in the
provisioner output, or `vagrant status` shows a VM as `running` but a
provisioner step never finished.

## Read the actual error

The provisioner output is logged. If you redirected `vagrant up` to a file
(as the tutorial suggests):

```bash
grep -vE '^\[K' vagrant-up.log | grep -E '(WARN|ERROR|Error|fail)' | tail -20
```

Otherwise scroll back through `vagrant up`'s output. The first `ERROR` or
`Error:` line is the cause — everything after is fallout.

## Re-run the provisioner

Provisioning is **idempotent** — re-running it after a partial failure is
safe and is how you recover.

```bash
vagrant provision <vmname>      # re-run all provisioners on one VM
vagrant provision                # re-run on every VM
```

If a VM is half-set-up and you want to start from a clean OS install:

```bash
vagrant destroy -f <vmname>
vagrant up <vmname>
```

## "Machine already provisioned"

```
==> control: Machine already provisioned. Run `vagrant provision` or use the
==> control: `--provision` flag to force provisioning.
```

This means Vagrant remembers a previous successful provisioner run. To force
re-provisioning even on an already-provisioned VM:

```bash
vagrant up --provision
```

## Provisioner SSH connection died mid-run

If you run `vagrant ssh` against a VM that is currently being provisioned by
another `vagrant up`, the provisioner's SSH session can be interrupted and
the remote script gets SIGHUP'd. Symptoms:

- `vagrant up` exits 0 but the lab is half-provisioned.
- No process inside the affected VM is doing anything.
- The provisioner log stops mid-output with no error.

Fix: do **not** open extra `vagrant ssh` sessions while `vagrant up` is
running. Re-provision the affected VM:

```bash
vagrant provision <vmname>
```

## Specific symptoms

### `Unit file firewalld.service does not exist`

The base image lacks `firewalld`. `scripts/common/base-setup.sh` installs it.
If you see this error, the dnf install line failed — either the host has
no internet on first run, or the lab mirror on the repo VM is not ready
yet. Confirm the repo VM provisioned successfully first, then re-run:

```bash
vagrant provision <vmname>
```

### `Failed to download metadata for repo 'lab-baseos'`

The managed node is configured to use the lab mirror on `repo-server`
(`/etc/yum.repos.d/lab-offline.repo`), but cannot reach it. Common causes:

- The `repo` VM is not running, or never finished its initial reposync.
  Check with `vagrant status` and look at the repo provisioner log.
- The lab subnet is broken. See
  [Troubleshoot the lab network](troubleshoot-network.md).

Bring `repo` up, then re-provision the affected node.

### `No match for argument: oniguruma-devel`

EPEL or CRB (CodeReady Builder) is not enabled on the control node.
`scripts/control/setup-control.sh` enables both, but EPEL is fetched
from the internet (not the lab mirror). If the control VM has no
internet during provisioning, EPEL fails and the pip fallback path for
`ansible-navigator` cannot build its dependencies. Either:

1. Provide internet and re-run `vagrant provision control`, or
2. Accept that `ansible-navigator` cannot be installed via pip on this
   run; it will only work with `--execution-environment true` once
   the EE image is available.

### `Failed to build onigurumacffi`

`oniguruma-devel` is missing on the control node — see above. EPEL + CRB
are required for the pip-fallback path.

### `cannot chdir to /home/vagrant: Permission denied`

The provisioner ran `sudo -u student <command>` from a working directory
that `student` cannot enter. The current code uses `runuser -l student -c
'...'` to avoid this. If you see this error on a current lab, you are on an
older version of the provisioner. Pull the latest changes and re-run
`vagrant provision control`.

### `The device type "lsilogic" specified for "scsi0" is not supported by vmrun`

Apple Silicon Fusion does not support SCSI lsilogic. The lab's Vagrantfile
declares extra disks with `vmware_desktop: { bus_type: 'nvme' }` to avoid
this. If you see this error, you are on an older Vagrantfile. Pull the
latest changes, then:

```bash
vagrant destroy -f
rm -rf disks/
vagrant up
```

## Related

- [Troubleshoot the lab network](troubleshoot-network.md).
- [Explanation: per-provider quirks](../explanation/per-provider-quirks.md).
