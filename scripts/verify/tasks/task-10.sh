#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 10 — hosts.j2 template + gen_hosts.yml producing /etc/myhosts on dev
TASK_NUM=10
TASK_TITLE="hosts.j2 → /etc/myhosts on dev"
TASK_POINTS=20

task_apply() {
    [[ -f "$ANSIBLE_DIR/gen_hosts.yml" ]] || { log_warn "gen_hosts.yml missing"; return 1; }
    playbook_idempotent gen_hosts.yml
}

task_verify() {
    score_check 1 "hosts.j2 exists"         test -f "$ANSIBLE_DIR/hosts.j2"
    score_check 1 "gen_hosts.yml exists"    test -f "$ANSIBLE_DIR/gen_hosts.yml"
    score_check 2 "hosts.j2 iterates groups['all']" \
        grep -Eq "for .* in groups\\['all'\\]|for .* in ansible_play_hosts" "$ANSIBLE_DIR/hosts.j2"
    score_check 2 "hosts.j2 references default_ipv4 / ansible_host" \
        grep -Eq 'default_ipv4|ansible_host' "$ANSIBLE_DIR/hosts.j2"

    local node
    for node in "${DEV_NODES[@]}"; do
        score_check 3 "${node}: /etc/myhosts exists"            node_sudo "$node" "test -f /etc/myhosts"
        score_check 3 "${node}: contains localhost line"        node_sudo "$node" "grep -q '127.0.0.1.*localhost' /etc/myhosts"
        # Expect a line per managed node
        local n
        for n in "${ALL_NODES[@]}"; do
            score_check 1 "${node}: /etc/myhosts has line for ${n}" \
                node_sudo "$node" "grep -Eq '\\b${n}(\\.|\\s)' /etc/myhosts"
        done
    done

    # Negative check: /etc/myhosts must NOT exist on non-dev groups
    local extra
    for extra in node2 node3 node5; do
        SCORE_MAX=$((SCORE_MAX + 1))
        if node_sudo "$extra" "test ! -f /etc/myhosts" >/dev/null 2>&1; then
            SCORE_POINTS=$((SCORE_POINTS + 1))
            SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+1) ${extra}: /etc/myhosts correctly absent")
        else
            SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/1) ${extra}: /etc/myhosts should not exist on non-dev")
        fi
    done
}

task_reboot_survival() { task_verify; }
