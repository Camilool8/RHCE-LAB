#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 7 — squid playbook for balancers
TASK_NUM=07
TASK_TITLE="squid.yml — squid role on balancers"
TASK_POINTS=10

task_apply() {
    [[ -f "$ANSIBLE_DIR/squid.yml" ]] || { log_warn "squid.yml missing"; return 1; }
    playbook_idempotent squid.yml
}

task_verify() {
    score_check 1 "squid.yml exists"            test -f "$ANSIBLE_DIR/squid.yml"
    score_check 2 "squid.yml targets balancers" grep -Eq '^\s*hosts:\s*balancers' "$ANSIBLE_DIR/squid.yml"
    # Accept all three canonical ways of including a role in a play:
    #   roles:
    #     - squid                       # YAML short form
    #     - role: squid                 # long form (what the reference uses)
    #     - name: squid                 # legacy long form
    # plus the include_role / import_role task style:
    #   ansible.builtin.include_role:
    #     name: squid
    score_check 2 "squid.yml uses squid role" \
        grep -Eq '^\s*(-\s*(role|name)?:?\s*)?squid\s*$|^\s*name:\s*squid\s*$' \
        "$ANSIBLE_DIR/squid.yml"
    local node
    for node in "${BALANCER_NODES[@]}"; do
        score_check 3 "${node}: squid installed"    node_sudo "$node" "rpm -q squid"
        score_check 2 "${node}: squid enabled or active" \
            node_sudo "$node" "systemctl is-enabled squid || systemctl is-active squid"
    done
}

task_reboot_survival() { task_verify; }
