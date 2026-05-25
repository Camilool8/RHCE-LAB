#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# scripts/verify/lib/common.sh
#
# Shared helpers for the RHCE-LAB task verifier. Sourced by verify-all.sh
# and every scripts/verify/tasks/task-NN.sh.
#
# Conventions:
#   * Tasks run on the control node as user "student" from /home/student/ansible.
#   * Each task script defines: TASK_NUM, TASK_TITLE, TASK_POINTS,
#     task_apply (optional), task_verify (required).
#   * Helpers below maintain SCORE_POINTS / SCORE_MAX / SCORE_DETAIL[] arrays
#     for the current task; verify-all.sh resets them between tasks.

set -o pipefail

# Non-interactive verify runs do not source profile.d; match setup-control.sh on aarch64.
if [ "$(uname -m)" = 'aarch64' ]; then
  PATH="/usr/local/bin:/usr/bin:/usr/sbin:${PATH}"
  export PATH
fi

ANSIBLE_DIR="${ANSIBLE_DIR:-/home/student/ansible}"
SSH_KEY="${SSH_KEY:-/home/student/.ssh/RH294-LAB}"
SSH_USER="${SSH_USER:-student}"
ALL_NODES=(node1 node2 node3 node4 node5)
DEV_NODES=(node1)
TEST_NODES=(node2)
PROD_NODES=(node3 node4)
BALANCER_NODES=(node5)
WEB_NODES=("${PROD_NODES[@]}")

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
    C_BLU=$'\033[34m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_DIM=''; C_BLD=''; C_OFF=''
fi

log_info()  { printf '%s[INFO]%s %s\n'  "$C_BLU" "$C_OFF" "$*" >&2; }
log_warn()  { printf '%s[WARN]%s %s\n'  "$C_YEL" "$C_OFF" "$*" >&2; }
log_error() { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; }
log_step()  { printf '%s==>%s %s\n'     "$C_BLU" "$C_OFF" "$*" >&2; }

# ---- scoring state (per-task; reset by verify-all.sh between tasks) ----
SCORE_POINTS=0
SCORE_MAX=0
SCORE_DETAIL=()

# score_check <points> <label> <0-on-pass-nonzero-on-fail>
# Drives in two ways: pass a command (eval'd) OR pre-compute and pass `true`/`false`.
score_check() {
    local pts="$1"; local label="$2"; shift 2
    SCORE_MAX=$((SCORE_MAX + pts))
    if "$@" >/dev/null 2>&1; then
        SCORE_POINTS=$((SCORE_POINTS + pts))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+${pts}) ${label}")
        return 0
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/${pts}) ${label}")
        return 1
    fi
}

# score_assert <points> <label> <expected_substring> <command...>
# Runs the command, captures stdout, passes if stdout contains the expected text.
score_assert() {
    local pts="$1"; local label="$2"; local expect="$3"; shift 3
    SCORE_MAX=$((SCORE_MAX + pts))
    local out
    out=$("$@" 2>&1) || true
    if printf '%s' "$out" | grep -qF -- "$expect"; then
        SCORE_POINTS=$((SCORE_POINTS + pts))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+${pts}) ${label}")
        return 0
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/${pts}) ${label} ${C_DIM}(expected '${expect}')${C_OFF}")
        return 1
    fi
}

# ---- remote helpers (SSH into managed nodes as student, sudo for state checks)
node_ssh() {
    local node="$1"; shift
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o ConnectTimeout=5 -o BatchMode=yes \
        -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        -i "$SSH_KEY" "${SSH_USER}@${node}" "$@"
}
node_sudo() {
    # Pipe the command via stdin to avoid all shell-quoting issues.
    # Wrapping commands in '...' breaks when they contain single quotes
    # (the remote shell hangs waiting for the closing quote).
    local node="$1"; shift
    printf '%s\n' "$*" | node_ssh "$node" "sudo -n bash -s"
}
nodes_each() {
    local cmd_func="$1"; shift
    local nodes=("$@"); local node rc=0
    for node in "${nodes[@]}"; do
        "$cmd_func" "$node" || rc=$?
    done
    return $rc
}

# ---- Ansible helpers (run as student, from $ANSIBLE_DIR) ----
ansible_run() {
    ( cd "$ANSIBLE_DIR" && env ANSIBLE_FORCE_COLOR=0 ansible "$@" )
}
ansible_playbook_run() {
    ( cd "$ANSIBLE_DIR" && env ANSIBLE_FORCE_COLOR=0 ansible-playbook "$@" )
}

# playbook_idempotent <playbook> [extra-args...]
#   * Runs the playbook twice.
#   * Returns 0 if the SECOND run reports `changed=0 failed=0` for every host.
#   * Returns 1 otherwise (and stashes second-run output in /tmp/verify-idem-<basename>.log).
playbook_idempotent() {
    local pb="$1"; shift
    local base; base=$(basename "$pb" .yml)
    local first_log="/tmp/verify-apply-${base}.log"
    local second_log="/tmp/verify-idem-${base}.log"
    log_step "applying ${pb} (first run)"
    if ! ansible_playbook_run "$pb" "$@" >"$first_log" 2>&1; then
        log_error "first apply of ${pb} failed; see $first_log"
        return 2
    fi
    log_step "applying ${pb} (second run, idempotency check)"
    if ! ansible_playbook_run "$pb" "$@" >"$second_log" 2>&1; then
        log_error "second apply of ${pb} failed; see $second_log"
        return 2
    fi
    # Parse PLAY RECAP lines; reject if any host has changed=[1-9] or failed=[1-9].
    if grep -E ':\s+ok=[0-9]+\s+changed=[1-9][0-9]*' "$second_log" >/dev/null \
       || grep -E '\sfailed=[1-9][0-9]*' "$second_log" >/dev/null \
       || grep -E '\sunreachable=[1-9][0-9]*' "$second_log" >/dev/null; then
        return 1
    fi
    return 0
}

# files_exist <file...>  — returns 0 if all exist
files_exist() {
    local f
    for f in "$@"; do
        [[ -e "$f" ]] || return 1
    done
    return 0
}

# reboot_nodes_and_wait <node...>
reboot_nodes_and_wait() {
    local nodes=("$@") node
    log_step "rebooting nodes: ${nodes[*]}"
    for node in "${nodes[@]}"; do
        node_sudo "$node" "systemctl reboot" >/dev/null 2>&1 || true
    done
    sleep 8
    for node in "${nodes[@]}"; do
        local tries=0
        while ! node_ssh "$node" 'true' >/dev/null 2>&1; do
            tries=$((tries + 1))
            if (( tries > 60 )); then
                log_error "node ${node} did not come back after reboot"
                return 1
            fi
            sleep 3
        done
    done
    log_info "all nodes responsive after reboot"
}

# pretty per-task header / footer
task_header() {
    printf '\n%s== Task %02d: %s (max %d) ==%s\n' "$C_BLD" "$1" "$2" "$3" "$C_OFF"
}
task_footer() {
    local task="$1" got="$2" max="$3"
    local color="$C_GRN"
    (( got < max )) && color="$C_YEL"
    (( got == 0 )) && color="$C_RED"
    printf '%s── task %02d score: %d/%d ──%s\n' "$color" "$task" "$got" "$max" "$C_OFF"
}

# Pretty-print the SCORE_DETAIL array under each task header.
print_score_detail() {
    local line
    for line in "${SCORE_DETAIL[@]}"; do
        printf '   %s\n' "$line"
    done
}
