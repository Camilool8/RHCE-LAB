#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034  # sourced via $LIB_DIR; SCORE_DETAIL consumed by sourced task files
# scripts/verify/verify-all.sh
#
# RHCE-LAB task verifier. Emulates the EX294 grader: per-task state checks,
# optional idempotency re-runs, optional reboot-survival pass, 300-point
# total with the standard 210/300 = 70 % passing line.
#
# Run as the 'student' user on the control node, from anywhere — the script
# cd's into $ANSIBLE_DIR (default /home/student/ansible) before running
# Ansible.
#
# Usage:
#   scripts/verify/verify-all.sh                 # check-only (state inspection)
#   scripts/verify/verify-all.sh --apply         # also (re-)run student playbooks
#   scripts/verify/verify-all.sh --reboot        # reboot managed nodes and re-verify
#   scripts/verify/verify-all.sh --task 5        # single task
#   scripts/verify/verify-all.sh --task 5,7,16   # comma-separated list
#   scripts/verify/verify-all.sh --list          # print task table and exit
#
# Exit code: 0 if total score >= PASS_THRESHOLD (default 210), 1 otherwise.

set -uo pipefail

# Requires bash 4+ (mapfile, associative arrays). AlmaLinux 9 ships bash 5.x;
# the failure case is running this on a macOS host where /bin/bash is 3.2.
if (( BASH_VERSINFO[0] < 4 )); then
    printf 'verify-all.sh requires bash 4+, found %s. Run this on the control node (AlmaLinux 9).\n' \
        "$BASH_VERSION" >&2
    exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB_DIR="${SCRIPT_DIR}/lib"
TASKS_DIR="${SCRIPT_DIR}/tasks"

# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

PASS_THRESHOLD="${PASS_THRESHOLD:-210}"

APPLY=0
REBOOT=0
TASKS_FILTER=""
LIST_ONLY=0

usage() {
    # Extract the header comment block (the lines between '# RHCE-LAB task...'
    # and the blank line before `set -uo pipefail`).
    awk '/^# RHCE-LAB task verifier/{p=1} p; /^# Exit code/{exit}' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while (($#)); do
    case "$1" in
        --apply)       APPLY=1 ;;
        --reboot)      REBOOT=1 ;;
        --task)        TASKS_FILTER="${2:-}"; shift ;;
        --task=*)      TASKS_FILTER="${1#*=}" ;;
        --list)        LIST_ONLY=1 ;;
        -h|--help)     usage 0 ;;
        *) log_error "unknown arg: $1"; usage 1 ;;
    esac
    shift
done

# Discover task scripts (task-01.sh .. task-18.sh)
TASK_SCRIPTS=()
shopt -s nullglob
for _s in "${TASKS_DIR}"/task-*.sh; do TASK_SCRIPTS+=("$_s"); done
shopt -u nullglob
# Sort alphabetically (sources are zero-padded, so this matches numeric order).
mapfile -t TASK_SCRIPTS < <(printf '%s\n' "${TASK_SCRIPTS[@]}" | sort)
if (( ${#TASK_SCRIPTS[@]} == 0 )); then
    log_error "no task scripts found in ${TASKS_DIR}"
    exit 1
fi

# Optional filter (comma-separated task numbers)
declare -A FILTER_SET
if [[ -n "$TASKS_FILTER" ]]; then
    IFS=',' read -ra _items <<<"$TASKS_FILTER"
    for n in "${_items[@]}"; do FILTER_SET["$(printf '%02d' "$n")"]=1; done
fi

# Sanity: are we on the control node?
if [[ ! -d "$ANSIBLE_DIR" ]]; then
    log_warn "ANSIBLE_DIR=${ANSIBLE_DIR} does not exist — student tasks may not be set up yet"
fi
if ! command -v ansible >/dev/null 2>&1; then
    log_warn "ansible not in PATH — most checks will fail. Run on the control node as 'student'."
fi

# --list: print metadata table and exit
if (( LIST_ONLY )); then
    printf '%-4s %-6s %s\n' "Task" "Pts" "Title"
    printf '%-4s %-6s %s\n' "----" "----" "-----"
    for s in "${TASK_SCRIPTS[@]}"; do
        TASK_NUM=""; TASK_TITLE=""; TASK_POINTS=""
        # shellcheck disable=SC1090
        source "$s"
        printf '%-4s %-6s %s\n' "$TASK_NUM" "$TASK_POINTS" "$TASK_TITLE"
        unset -f task_apply task_verify task_reboot_survival 2>/dev/null || true
    done
    exit 0
fi

GRAND_POINTS=0
GRAND_MAX=0
declare -a RESULTS_LINES=()

run_task_script() {
    local script="$1"
    # Reset per-task scoring + hooks before sourcing.
    SCORE_POINTS=0
    SCORE_MAX=0
    SCORE_DETAIL=()
    TASK_NUM=""; TASK_TITLE=""; TASK_POINTS=0
    unset -f task_apply task_verify task_reboot_survival 2>/dev/null || true

    # shellcheck disable=SC1090
    source "$script"

    if [[ -n "$TASKS_FILTER" ]] && [[ -z "${FILTER_SET[$TASK_NUM]:-}" ]]; then
        return 0
    fi

    task_header "${TASK_NUM#0}" "$TASK_TITLE" "$TASK_POINTS"

    # Apply step (re-run student playbooks + idempotency check) — only when requested.
    if (( APPLY )) && declare -F task_apply >/dev/null; then
        task_apply || log_warn "task_apply for ${TASK_NUM} returned non-zero (see /tmp/verify-*.log)"
    fi

    # State verification (always run).
    if declare -F task_verify >/dev/null; then
        task_verify || true
    else
        log_warn "task ${TASK_NUM} has no task_verify function"
    fi

    print_score_detail
    task_footer "${TASK_NUM#0}" "$SCORE_POINTS" "$SCORE_MAX"

    GRAND_POINTS=$((GRAND_POINTS + SCORE_POINTS))
    # Use TASK_POINTS as the authoritative max so totals stay stable
    # even if a verifier skipped some checks (e.g. host unreachable).
    GRAND_MAX=$((GRAND_MAX + TASK_POINTS))
    RESULTS_LINES+=("$(printf 'Task %s: %3d / %3d   %s' "$TASK_NUM" "$SCORE_POINTS" "$TASK_POINTS" "$TASK_TITLE")")
}

# ---- pass 1: apply + verify ----
log_step "Pass 1: state verification${APPLY:+ + apply}"
for s in "${TASK_SCRIPTS[@]}"; do
    run_task_script "$s"
done

# ---- pass 2: reboot survival ----
if (( REBOOT )); then
    log_step "Pass 2: rebooting managed nodes for survival check"
    if ! reboot_nodes_and_wait "${ALL_NODES[@]}"; then
        log_error "reboot/recovery failed; skipping survival pass"
    else
        GRAND_POINTS=0; GRAND_MAX=0
        RESULTS_LINES=()
        log_step "re-verifying state after reboot"
        for s in "${TASK_SCRIPTS[@]}"; do
            SCORE_POINTS=0; SCORE_MAX=0; SCORE_DETAIL=()
            TASK_NUM=""; TASK_TITLE=""; TASK_POINTS=0
            unset -f task_apply task_verify task_reboot_survival 2>/dev/null || true
            # shellcheck disable=SC1090
            source "$s"
            if [[ -n "$TASKS_FILTER" ]] && [[ -z "${FILTER_SET[$TASK_NUM]:-}" ]]; then continue; fi
            task_header "${TASK_NUM#0}" "${TASK_TITLE} (post-reboot)" "$TASK_POINTS"
            if declare -F task_reboot_survival >/dev/null; then
                task_reboot_survival || true
            elif declare -F task_verify >/dev/null; then
                task_verify || true
            fi
            print_score_detail
            task_footer "${TASK_NUM#0}" "$SCORE_POINTS" "$SCORE_MAX"
            GRAND_POINTS=$((GRAND_POINTS + SCORE_POINTS))
            GRAND_MAX=$((GRAND_MAX + TASK_POINTS))
            RESULTS_LINES+=("$(printf 'Task %s: %3d / %3d   %s' "$TASK_NUM" "$SCORE_POINTS" "$TASK_POINTS" "$TASK_TITLE")")
        done
    fi
fi

# ---- summary ----
printf '\n%s===== Score Summary =====%s\n' "$C_BLD" "$C_OFF"
for line in "${RESULTS_LINES[@]}"; do
    printf '%s\n' "$line"
done

# When no filter, totals are over the full 300; when filtered, over the filtered max.
EFFECTIVE_PASS="$PASS_THRESHOLD"
if [[ -n "$TASKS_FILTER" ]]; then
    EFFECTIVE_PASS=$(( GRAND_MAX * 70 / 100 ))
fi

printf '\n%s----- Total: %d / %d -----%s\n' "$C_BLD" "$GRAND_POINTS" "$GRAND_MAX" "$C_OFF"
printf 'Passing line: %d / %d (70%%)\n' "$EFFECTIVE_PASS" "$GRAND_MAX"

if (( GRAND_POINTS >= EFFECTIVE_PASS )); then
    printf '%sRESULT: PASS%s\n' "$C_GRN" "$C_OFF"
    exit 0
else
    printf '%sRESULT: FAIL%s\n' "$C_RED" "$C_OFF"
    exit 1
fi
