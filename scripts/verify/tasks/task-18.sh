#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 18 — selinux.yml (permissive) + selinux2.yml (enforcing via ansible-navigator)
TASK_NUM=18
TASK_TITLE="selinux role — permissive then enforcing (via ansible-navigator)"
TASK_POINTS=20

# Per-session flag: set to 1 by task_apply when ansible-navigator is actually invoked
# during this grader run. Avoids awarding the bonus from a stale log left by a previous run.
_SELINUX2_NAV_RAN=0

task_apply() {
    if [[ -f "$ANSIBLE_DIR/selinux.yml" ]]; then
        ansible_playbook_run selinux.yml >/tmp/verify-apply-selinux.log 2>&1 || \
            log_warn "selinux.yml first apply non-zero (often because reboot required)"
    fi
    if [[ -f "$ANSIBLE_DIR/selinux2.yml" ]]; then
        # The task explicitly says: execute selinux2.yml using ansible-navigator.
        if command -v ansible-navigator >/dev/null 2>&1; then
            ( cd "$ANSIBLE_DIR" && ansible-navigator run selinux2.yml -m stdout ) \
                >/tmp/verify-apply-selinux2-nav.log 2>&1 || true
            _SELINUX2_NAV_RAN=1
        else
            ansible_playbook_run selinux2.yml >/tmp/verify-apply-selinux2.log 2>&1 || \
                log_warn "selinux2.yml apply non-zero (often because reboot required)"
        fi
    fi
}

task_verify() {
    score_check 1 "selinux.yml exists"   test -f "$ANSIBLE_DIR/selinux.yml"
    score_check 1 "selinux2.yml exists"  test -f "$ANSIBLE_DIR/selinux2.yml"
    score_check 2 "selinux.yml sets state permissive" \
        grep -Eq 'selinux_state:\s*permissive' "$ANSIBLE_DIR/selinux.yml"
    score_check 2 "selinux2.yml sets state enforcing" \
        grep -Eq 'selinux_state:\s*enforcing' "$ANSIBLE_DIR/selinux2.yml"

    # Final state on every node must be enforcing AND survive reboot (i.e. /etc/selinux/config updated).
    local node
    for node in "${ALL_NODES[@]}"; do
        score_check 2 "${node}: getenforce == Enforcing (runtime)" \
            node_sudo "$node" "test \"\$(getenforce)\" = Enforcing"
        score_check 1 "${node}: /etc/selinux/config has SELINUX=enforcing (reboot-survival)" \
            node_sudo "$node" "grep -Eq '^SELINUX=enforcing' /etc/selinux/config"
    done

    # Bonus: was ansible-navigator actually used for selinux2.yml in this grader session?
    # Uses a per-session variable set by task_apply to avoid awarding the point from a
    # stale log file left by a previous --apply run.
    SCORE_MAX=$((SCORE_MAX + 1))
    if [[ "${_SELINUX2_NAV_RAN:-0}" == "1" ]]; then
        SCORE_POINTS=$((SCORE_POINTS + 1))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+1) ansible-navigator was used for selinux2.yml")
    else
        SCORE_DETAIL+=("${C_YEL}WARN${C_OFF} ( 0/1) selinux2.yml not detected as run via ansible-navigator (re-run with --apply)")
    fi
}

task_reboot_survival() {
    # The strongest signal — after a reboot, SELinux remains enforcing because /etc/selinux/config
    # is what the kernel reads on boot.
    local node
    for node in "${ALL_NODES[@]}"; do
        score_check 3 "${node}: post-reboot getenforce == Enforcing" \
            node_sudo "$node" "test \"\$(getenforce)\" = Enforcing"
    done
}
