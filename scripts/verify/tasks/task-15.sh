#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 15 — cron.yml: every 2 min, logger "EX294 exam in progress", as user natasha
TASK_NUM=15
TASK_TITLE="cron.yml — natasha cron job */2 logger 'EX294 exam in progress'"
TASK_POINTS=15

task_apply() {
    [[ -f "$ANSIBLE_DIR/cron.yml" ]] || { log_warn "cron.yml missing"; return 1; }
    playbook_idempotent cron.yml
}

task_verify() {
    score_check 1 "cron.yml exists" test -f "$ANSIBLE_DIR/cron.yml"

    local node
    for node in "${ALL_NODES[@]}"; do
        score_check 1 "${node}: user natasha exists"  node_sudo "$node" "id natasha"
        score_check 1 "${node}: natasha crontab present" \
            node_sudo "$node" "crontab -l -u natasha 2>/dev/null | grep -q logger"
        score_check 1 "${node}: cron runs every 2 minutes" \
            node_sudo "$node" "crontab -l -u natasha 2>/dev/null | grep -qE '^\\*/2 '"
    done

    # Exact command string check on one node
    score_check 2 "node1: cron job exact command (logger \"EX294 exam in progress\")" \
        node_sudo node1 "crontab -l -u natasha 2>/dev/null | grep -F 'logger \"EX294 exam in progress\"'"
}

task_reboot_survival() {
    # After reboot, crontab still listed (cron entries are in /var/spool/cron — durable).
    task_verify
}
