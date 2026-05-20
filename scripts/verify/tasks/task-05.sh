#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 5 — apache role + apache-role.yml against webservers group
TASK_NUM=05
TASK_TITLE="apache role — httpd + firewalld + templated index.html"
TASK_POINTS=25

task_apply() {
    [[ -f "$ANSIBLE_DIR/apache-role.yml" ]] || { log_warn "apache-role.yml missing"; return 1; }
    playbook_idempotent apache-role.yml
}

task_verify() {
    local role="$ANSIBLE_DIR/roles/apache"
    score_check 1 "roles/apache directory exists" test -d "$role"
    score_check 1 "apache-role.yml exists"        test -f "$ANSIBLE_DIR/apache-role.yml"
    score_check 2 "role has tasks/main.yml"       test -f "$role/tasks/main.yml"
    score_check 2 "role has templates/index.html.j2" test -f "$role/templates/index.html.j2"

    # Template references both HOSTNAME and IPADDRESS facts (grep liberally for any
    # of the standard fact names — fqdn / inventory_hostname / hostname).
    score_check 2 "template references a hostname fact"  grep -Eq 'ansible_(fqdn|hostname)|inventory_hostname' "$role/templates/index.html.j2"
    score_check 2 "template references an IP fact"       grep -Eq 'default_ipv4|ansible_host' "$role/templates/index.html.j2"

    local node
    for node in "${WEB_NODES[@]}"; do
        score_check 2 "${node}: httpd active"               node_sudo "$node" "systemctl is-active httpd"
        score_check 1 "${node}: httpd enabled"              node_sudo "$node" "systemctl is-enabled httpd"
        score_check 1 "${node}: firewalld http service permitted" \
            node_sudo "$node" "firewall-cmd --list-services --permanent | grep -qw http || firewall-cmd --list-services | grep -qw http"
        score_check 2 "${node}: GET /  contains hostname text" \
            node_sudo "$node" "curl -s http://localhost/ | grep -Eq 'Welcome to .*${node}'"
    done
}

task_reboot_survival() { task_verify; }
