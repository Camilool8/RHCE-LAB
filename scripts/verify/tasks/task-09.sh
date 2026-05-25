#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 9 — ansible-vault: vault.yml + password.txt (rh294lab); dev_pass=redhat, mgr_pass=linux
TASK_NUM=09
TASK_TITLE="ansible-vault — vault.yml + password.txt"
TASK_POINTS=10
VAULT_PW_INITIAL="${VAULT_PW_INITIAL:-rh294lab}"

task_verify() {
    local vault="$ANSIBLE_DIR/vault.yml"
    local pwfile="$ANSIBLE_DIR/password.txt"

    score_check 1 "vault.yml exists"                 test -f "$vault"
    score_check 1 "password.txt exists"              test -f "$pwfile"
    score_check 2 "vault.yml is encrypted (\$ANSIBLE_VAULT header)" \
        bash -c "head -1 '$vault' | grep -q '^\$ANSIBLE_VAULT'"

    # Decryption: try the file's own password first (this is what the student maintains
    # during the exam). If task 13 has run, the password is now 'ansible' — accept it.
    local decrypted=""
    if [[ -f "$pwfile" ]]; then
        decrypted=$( ( cd "$ANSIBLE_DIR" && ansible-vault view vault.yml --vault-password-file=./password.txt ) 2>/dev/null || true )
    fi
    if [[ -z "$decrypted" ]]; then
        decrypted=$( ( cd "$ANSIBLE_DIR" && echo "$VAULT_PW_INITIAL" | ansible-vault view vault.yml --vault-password-file=/dev/stdin ) 2>/dev/null || true )
    fi

    SCORE_MAX=$((SCORE_MAX + 2))
    if grep -qE '^\s*dev_pass:\s*redhat\s*$' <<<"$decrypted"; then
        SCORE_POINTS=$((SCORE_POINTS + 2))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+2) vault contains dev_pass=redhat")
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/2) vault must contain dev_pass=redhat")
    fi

    SCORE_MAX=$((SCORE_MAX + 2))
    if grep -qE '^\s*mgr_pass:\s*linux\s*$' <<<"$decrypted"; then
        SCORE_POINTS=$((SCORE_POINTS + 2))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+2) vault contains mgr_pass=linux")
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/2) vault must contain mgr_pass=linux")
    fi

    SCORE_MAX=$((SCORE_MAX + 2))
    # Accept either 'rh294lab' (pre-task-13) or 'ansible' (post-task-13)
    local pw=""; [[ -f "$pwfile" ]] && pw=$(<"$pwfile")
    pw=${pw//[$'\t\r\n ']/}
    if [[ "$pw" == "rh294lab" || "$pw" == "ansible" ]]; then
        SCORE_POINTS=$((SCORE_POINTS + 2))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+2) password.txt holds an accepted vault password ($pw)")
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/2) password.txt must contain 'rh294lab' or 'ansible' (got: '$pw')")
    fi
}
