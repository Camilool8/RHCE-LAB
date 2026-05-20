#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 3 — packages.yml: php+mariadb on dev/test/prod; RPM Dev Tools on dev; update all on dev.
TASK_NUM=03
TASK_TITLE="packages.yml — php/mariadb + dev tools group + updates"
TASK_POINTS=15

task_apply() {
    [[ -f "$ANSIBLE_DIR/packages.yml" ]] || { log_warn "packages.yml missing"; return 1; }
    # `dnf state: latest` is the canonical false-positive for idempotency, so we
    # apply once but only fail idempotency if the second run *fails* (not on
    # changed=1, which is expected here). Implemented inline:
    ansible_playbook_run packages.yml >/tmp/verify-apply-packages.log 2>&1 || \
        { log_error "packages.yml first apply failed"; return 2; }
    ansible_playbook_run packages.yml >/tmp/verify-idem-packages.log 2>&1 || \
        { log_error "packages.yml second apply failed"; return 2; }
}

task_verify() {
    score_check 1 "packages.yml exists" test -f "$ANSIBLE_DIR/packages.yml"

    local node
    for node in "${DEV_NODES[@]}" "${TEST_NODES[@]}" "${PROD_NODES[@]}"; do
        score_check 1 "${node}: php installed"     node_sudo "$node" "rpm -q php"
        score_check 1 "${node}: mariadb installed" node_sudo "$node" "rpm -q mariadb"
    done
    for node in "${BALANCER_NODES[@]}"; do
        SCORE_MAX=$((SCORE_MAX + 1))
        if ! node_sudo "$node" "rpm -q php" >/dev/null 2>&1; then
            SCORE_POINTS=$((SCORE_POINTS + 1))
            SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+1) ${node}: php NOT installed (correctly excluded)")
        else
            SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/1) ${node}: php should not be installed")
        fi
    done
    for node in "${DEV_NODES[@]}"; do
        score_check 2 "${node}: RPM Development Tools group installed" \
            node_sudo "$node" "dnf group list --installed 2>/dev/null | grep -qi 'RPM Development Tools'"
    done
}

task_reboot_survival() { task_verify; }
