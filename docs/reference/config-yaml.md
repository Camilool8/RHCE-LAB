# `config.yaml`

Single configuration file at the repository root. Every value listed here
can be edited without touching the Vagrantfile.

## Full schema

```yaml
network:
  subnet: "192.168.56" # first three octets of the lab subnet
  netmask: "255.255.255.0"

vms:
  repo_server:
    hostname: "repo-server"
    ip: "192.168.56.40" # must match the `network.subnet` above
    memory: 1024 # MB
    cpus: 2

  control:
    hostname: "ansible-control"
    ip: "192.168.56.50"
    memory: 2048
    cpus: 2

  nodes:
    count: 5 # how many managed nodes (node1..nodeN)
    base_ip:
      51 # node1 = {subnet}.{base_ip},
      # node2 = {subnet}.{base_ip+1}, ...
    memory: 1280
    cpus: 1
    extra_disks:
      - size: 2 # GB. First extra disk (raw, task 17)
      - size: 2 # GB. Second extra disk (research VG, task 16)

box:
  name: "almalinux/9" # Vagrant Cloud box

lab:
  ansible_user: "student" # Linux user that owns the practice work
  ssh_key_name: "RH294-LAB" # files/keys/<this name> + .pub are generated
  time_server: "172.25.254.250" # exam-canonical NTP server (task 4)

providers:
  default: "" # blank = auto-detect; set to a provider name to pin
  virtualbox: { enabled: true }
  libvirt: { enabled: true, network_name: "rhce-lab" }
  parallels: { enabled: true }
  vmware_desktop: { enabled: true }
```

## Field-by-field reference

### `network.subnet`

First three octets of the lab subnet. Per-VM IPs must use this same prefix.
Default `192.168.56` — change only on subnet conflict.

### `network.netmask`

Always `255.255.255.0` (a /24). The lab assumes /24 in firewalld and NFS
rules; do not change without also editing those.

### `vms.repo_server.*`, `vms.control.*`

Per-VM IP, RAM (MB), CPU count, and hostname. Edit `memory` and `cpus`
freely. Edit `ip` if you also change `network.subnet`.

### `vms.nodes.count`

Number of managed nodes. Default 5 matches the EX294 task expectations. The
reference solutions assume `node1` through `node5`; reducing `count` will
break tasks that target specific nodes.

### `vms.nodes.base_ip`

The last octet of node1's IP. node2 is `base_ip + 1`, etc. Defaults give
node1 = `.51` through node5 = `.55`.

### `vms.nodes.memory` / `cpus`

Per-node RAM (MB) and CPU count. Applied uniformly to all `count` nodes.

### `vms.nodes.extra_disks`

A list. Each entry adds one extra virtual disk to **every** node. The lab
expects exactly two entries — task 17 uses the first, the lab provisioner
turns the second into the `research` VG. Size is in GB.

### `box.name`

Vagrant Cloud box reference. Default `almalinux/9` is multi-arch (amd64 +
arm64) and multi-provider. Alternatives:

- `generic/rhel9` — true RHEL, requires a subscription.
- `bento/rockylinux-9` — Rocky 9 family.
- `almalinux/9.aarch64` — legacy arm64-only AlmaLinux box (fallback if
  `almalinux/9` ever lacks the arm64 variant for your provider).

### `lab.ansible_user`

User created on every VM with passwordless sudo, used by the student. The
RHCE task descriptions hard-code paths like `/home/student/ansible/...`, so
changing this from `student` will break the reference solutions.

### `lab.ssh_key_name`

Name of the SSH keypair generated on the host at `files/keys/<name>` and
`<name>.pub`. The pair is distributed to control (private + public) and to
each managed node (public only). Default `RH294-LAB` matches the exam.

### `lab.time_server`

NTP server address used by task 4. Default is the standard exam value;
override if you want task 4 to point at a real server.

### `providers.default`

Provider name to use when [`LAB_PROVIDER`](overrides.md) is unset and no
`vagrant --provider` is passed. Blank = auto-detect from host OS + arch.

### `providers.<name>.enabled`

Cosmetic — there is no actual disabling logic; if a provider is unsupported
on your host, Vagrant simply errors when you select it. Leave `true`.

### `providers.libvirt.network_name`

libvirt's network name for the private subnet. Edit only if you have a
conflicting network in libvirt already.

## Related

- [Provider matrix](provider-matrix.md).
- [Topology](topology.md) — what these settings produce.
- [How-to: change the lab subnet](../how-to/change-lab-subnet.md).
