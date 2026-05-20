# RHCE-LAB

A 7-VM Ansible practice lab for the **RHCE 9 (EX294)** exam. Deployed with
Vagrant. Runs natively on macOS, Linux, and Windows on `x86_64` or `arm64`.

**Fully offline after first boot.** The repo VM mirrors AlmaLinux 9
BaseOS + AppStream during initial provisioning (the one moment internet
is required), and every managed node uses that mirror as its only dnf
source. After the first `vagrant up`, the lab works without an internet
connection.

**EX294-style grader included.** `scripts/verify/verify-all.sh` scores
your work the way the real exam grades: per-task state checks,
idempotency re-runs, and reboot-survival pass, totaling 300 points with
the standard 210/300 (70 %) passing line.

## I want to…

- **Set up the lab for the first time** → [Tutorial: first run](docs/tutorial/first-run.md)
- **Install the prerequisites for my OS** → [Install prerequisites](docs/how-to/install-prerequisites.md)
- **Start, stop, or reset the lab** → [Start, stop, reset](docs/how-to/start-stop-reset.md)
- **Take or restore a clean snapshot** → [Snapshot and revert](docs/how-to/snapshot-and-revert.md)
- **Work through one of the 18 exam tasks** → [Practice a task](docs/how-to/practice-a-task.md)
- **Score my work against the grader** → [Task verifier](scripts/verify/README.md)
- **Use `ansible-navigator`** → [Use ansible-navigator](docs/how-to/use-ansible-navigator.md)
- **Understand how the offline mirror works** → [Offline package mirror](docs/explanation/offline-mirror.md)
- **Look something up (IPs, accounts, paths)** → [Reference index](docs/reference/)
- **Understand a design decision** → [Explanation index](docs/explanation/)

Full documentation index: [`docs/`](docs/README.md).

## License

MIT.
