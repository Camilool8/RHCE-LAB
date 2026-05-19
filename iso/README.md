# ISO Folder

Drop a RHEL 9 or AlmaLinux 9 **DVD ISO** here (optional).

- **With an ISO present:** the repo server copies the full BaseOS and
  AppStream package trees from the ISO. The lab then has a complete offline
  package mirror.
- **Without an ISO:** the repo server creates empty-but-valid BaseOS and
  AppStream repository structures (enough for task 2's `file://` repo task).
  Managed nodes use the AlmaLinux internet mirrors for actual package
  installs, so an internet connection is needed during practice.

Only the first `*.iso` file found here is used.
