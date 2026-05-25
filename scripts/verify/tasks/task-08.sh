#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 8 — test.yml: /webtest dir + symlink + setgid + index.html
TASK_NUM=08
TASK_TITLE="test.yml — /webtest setgid dir + symlink + index.html"
TASK_POINTS=20

task_apply() {
    [[ -f "$ANSIBLE_DIR/test.yml" ]] || { log_warn "test.yml missing"; return 1; }
    playbook_idempotent test.yml
}

task_verify() {
    score_check 1 "test.yml exists" test -f "$ANSIBLE_DIR/test.yml"
    local node
    for node in "${TEST_NODES[@]}"; do
        score_check 2 "${node}: /webtest directory exists"          node_sudo "$node" "test -d /webtest"
        score_check 2 "${node}: /webtest group is webtest"          node_sudo "$node" "stat -c '%G' /webtest | grep -qx webtest"
        # Permissions: rwx,r-x,r-x => 0775; plus setgid => 2775. Accept either 2770 (no o+rx) or 2775.
        score_check 3 "${node}: /webtest mode 2775 (rwxrwsr-x)"     node_sudo "$node" "stat -c '%a' /webtest | grep -Eqx '(2775|2770)'"
        score_check 3 "${node}: /webtest has setgid bit"            node_sudo "$node" "stat -c '%A' /webtest | grep -q 's'"
        score_check 3 "${node}: /var/www/html/webtest is a symlink → /webtest" \
            node_sudo "$node" "test -L /var/www/html/webtest && [ \"\$(readlink /var/www/html/webtest)\" = /webtest ]"
        score_check 3 "${node}: /webtest/index.html contains 'Testing'" \
            node_sudo "$node" "grep -qx 'Testing.' /webtest/index.html || grep -qx 'Testing' /webtest/index.html"
        score_check 3 "${node}: index.html readable through symlink" \
            node_sudo "$node" "grep -q 'Testing' /var/www/html/webtest/index.html"
    done
}

task_reboot_survival() { task_verify; }
