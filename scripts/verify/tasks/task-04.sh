#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 4 — timesync system role: iburst, server 172.25.254.250
TASK_NUM=04
TASK_TITLE="timesync system role"
TASK_POINTS=15
TIME_SERVER="${TIME_SERVER:-172.25.254.250}"

task_apply() {
    [[ -f "$ANSIBLE_DIR/timesync.yml" ]] || { log_warn "timesync.yml missing"; return 1; }
    playbook_idempotent timesync.yml
}

task_verify() {
    score_check 1 "timesync.yml exists"     test -f "$ANSIBLE_DIR/timesync.yml"
    score_check 1 "rhel-system-roles RPM installed OR role downloaded via galaxy" \
        bash -c "rpm -q rhel-system-roles >/dev/null 2>&1 || test -d '$ANSIBLE_DIR/roles/linux-system-roles.timesync'"

    local node
    for node in "${ALL_NODES[@]}"; do
        score_check 2 "${node}: chrony.conf points at ${TIME_SERVER}" \
            node_sudo "$node" "grep -E '^(server|pool)\\s+${TIME_SERVER}' /etc/chrony.conf"
        SCORE_MAX=$((SCORE_MAX - 2)); SCORE_MAX=$((SCORE_MAX + 2))  # noop; readability
    done
    # iburst presence (single check across nodes — chrony.conf is identical)
    score_check 2 "node1: server line has iburst" \
        node_sudo node1 "grep -E '^(server|pool)\\s+${TIME_SERVER}.*iburst' /etc/chrony.conf"
    score_check 2 "node1: chronyd enabled" \
        node_sudo node1 "systemctl is-enabled chronyd"
}

task_reboot_survival() {
    # Persistence is the actual signal here — chrony service must be enabled,
    # /etc/chrony.conf must still have our server.
    task_verify
}
