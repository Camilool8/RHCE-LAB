#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 11 — hwreport.yml writes /root/hwreport.txt with 3 key=value lines.
TASK_NUM=11
TASK_TITLE="hwreport.yml — /root/hwreport.txt on all nodes"
TASK_POINTS=15

task_apply() {
    [[ -f "$ANSIBLE_DIR/hwreport.yml" ]] || { log_warn "hwreport.yml missing"; return 1; }
    playbook_idempotent hwreport.yml
}

task_verify() {
    score_check 1 "hwreport.yml exists" test -f "$ANSIBLE_DIR/hwreport.yml"

    local node
    for node in "${ALL_NODES[@]}"; do
        score_check 1 "${node}: /root/hwreport.txt exists" node_sudo "$node" "test -f /root/hwreport.txt"
        score_check 1 "${node}: has INVENTORY_HOSTNAME="  node_sudo "$node" "grep -Eq '^INVENTORY_HOSTNAME=' /root/hwreport.txt"
        score_check 1 "${node}: has TOTAL_MEMORY_IN_MB="  node_sudo "$node" "grep -Eq '^TOTAL_MEMORY_IN_MB=[0-9]+' /root/hwreport.txt"
        # BIOS_VERSION may be 'NONE' on some hypervisors that don't expose it. Accept either.
        score_check 1 "${node}: has BIOS_VERSION="        node_sudo "$node" "grep -Eq '^BIOS_VERSION=' /root/hwreport.txt"
    done
}

task_reboot_survival() { task_verify; }
