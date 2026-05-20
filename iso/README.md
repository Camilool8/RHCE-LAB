# ISO Folder

Drop a RHEL 9 or AlmaLinux 9 **DVD ISO** here (optional).

- **With an ISO present:** the repo server copies the full BaseOS and
  AppStream package trees from the ISO. The lab then has a complete offline
  package mirror. The ISO is attached read-only to the repo VM and gets the
  right syntax for each Vagrant provider (VirtualBox/VMware via `config.vm.disk
  :dvd`, libvirt via `libvirt.storage :file device: :cdrom`, Parallels via
  `prlctl set ... --device-set cdrom0`, QEMU via `-drive media=cdrom`).
- **Without an ISO:** the repo server creates empty-but-valid BaseOS and
  AppStream repository structures (enough for task 2's `file://` repo task).
  Managed nodes use the AlmaLinux internet mirrors for actual package
  installs, so an internet connection is needed during practice.

Only the first `*.iso` file found here is used.
