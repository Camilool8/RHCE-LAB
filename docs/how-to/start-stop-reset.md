# Start, stop, and reset the lab

All commands below run from the lab repository root (`RHCE-LAB/`). On macOS
Apple Silicon with VMware Fusion you must export `LAB_PROVIDER=vmware_desktop`
first or prefix every command with it.

## Start the lab

Start every VM:

```bash
vagrant up
```

Start only one VM:

```bash
vagrant up node1
```

## Stop the lab

Graceful shutdown of every VM (keeps state on disk):

```bash
vagrant halt
```

Stop just one VM:

```bash
vagrant halt node1
```

## Suspend (pause memory)

Faster than `halt` because the VM's memory is paged to disk instead of the OS
shutting down. Resumes in seconds.

```bash
vagrant suspend           # all VMs
vagrant resume            # all VMs
vagrant suspend node1     # just one
```

## Reset the lab from a clean baseline

Use snapshots, not destroy. See [Snapshot and revert](snapshot-and-revert.md).
Restoring a snapshot is seconds; destroying and re-provisioning means
re-running `dnf reposync` on the repo server (up to 20 minutes) plus the
rest of provisioning (~10 minutes), so 30+ minutes per cycle.

## Destroy and rebuild

If a VM is genuinely broken, destroy it and `vagrant up` will recreate it:

```bash
vagrant destroy -f node1
vagrant up node1
```

A single node rebuild does NOT trigger the reposync — that only runs on
the `repo` VM.

To wipe the whole lab and start over (including the offline mirror):

```bash
vagrant destroy -f
rm -rf disks/
vagrant up
```

This re-downloads the BaseOS + AppStream mirror from the internet.
[Offline package mirror](../explanation/offline-mirror.md) explains why.

## See the current state of every VM

```bash
vagrant status
```

Output column meanings:

- `running` — VM is up.
- `not running` — VM exists but is shut down.
- `not created` — Vagrant has never built this VM.
- `suspended` — paused via `vagrant suspend`.

## Related

- [Snapshot and revert](snapshot-and-revert.md) — fastest way back to a known-good state.
- [Troubleshoot a provisioner failure](troubleshoot-provisioning.md) — when `vagrant up` fails partway.
