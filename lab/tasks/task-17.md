17. Create and use partitions:

Create /home/student/ansible/partition.yml, which creates partitions on all
the managed nodes:

    a) Each managed node has one additional raw (unpartitioned) data disk
       attached. Do NOT hard-code the device name — the exact path differs
       by hypervisor (it may be /dev/sdb, /dev/vdb, /dev/nvme0n2, …).
       Discover the disk at runtime from ansible_facts.devices.
    b) On the discovered disk, create a 1200 MiB primary partition,
       partition number 1, and format it as ext4.
    c) On hosts in the prod group, permanently mount that partition at
       /srv (i.e. the mount must survive a reboot).
    d) If 1200 MiB doesn't fit on the disk, print "Could not create
       partition of that size" and create an 800 MiB partition instead.
    e) If no raw data disk is found, print "this disk does not exist."

Hint: ansible_facts.devices is a dict keyed by short device name (e.g.
"vdb"), where each value has a 'partitions' dict (empty for raw disks)
and a 'size' string. Filter to entries with no partitions and exclude
the OS root disk.
