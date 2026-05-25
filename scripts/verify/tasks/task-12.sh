#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 12 — /etc/issue per group: Development / Test / Production
TASK_NUM=12
TASK_TITLE="issue.yml — /etc/issue per host group"
TASK_POINTS=15

task_apply() {
    [[ -f "$ANSIBLE_DIR/issue.yml" ]] || { log_warn "issue.yml missing"; return 1; }
    playbook_idempotent issue.yml
}

_grep_issue() { node_sudo "$1" "tr -d '\\n' < /etc/issue | grep -qx '$2' || head -1 /etc/issue | grep -qx '$2'"; }

task_verify() {
    score_check 1 "issue.yml exists" test -f "$ANSIBLE_DIR/issue.yml"

    local node
    for node in "${DEV_NODES[@]}"; do
        score_check 3 "${node} (dev): /etc/issue == Development"  _grep_issue "$node" "Development"
        score_check 1 "${node} (dev): /etc/issue has exactly one line" \
            node_sudo "$node" "[ \$(wc -l < /etc/issue) -eq 1 ]"
    done
    for node in "${TEST_NODES[@]}"; do
        score_check 3 "${node} (test): /etc/issue == Test"        _grep_issue "$node" "Test"
        score_check 1 "${node} (test): /etc/issue has exactly one line" \
            node_sudo "$node" "[ \$(wc -l < /etc/issue) -eq 1 ]"
    done
    for node in "${PROD_NODES[@]}"; do
        score_check 2 "${node} (prod): /etc/issue == Production"  _grep_issue "$node" "Production"
        score_check 1 "${node} (prod): /etc/issue has exactly one line" \
            node_sudo "$node" "[ \$(wc -l < /etc/issue) -eq 1 ]"
    done
}

task_reboot_survival() { task_verify; }
