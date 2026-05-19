Create inventory file for Ansible with the following content:

```inventory
[dev]
node1

[test]
node2

[prod]
node3
node4

[balancers]
node5

[webservers:children]
prod
```

Create `ansible.cfg` file with the following content:

```ansible.cfg
[defaults]
inventory=./inventory
roles_path=./roles
collections_path=./mycollection
remote_user=x69van
host_key_checking=False
private_key_file=~/.ssh/RH294-LAB
```
