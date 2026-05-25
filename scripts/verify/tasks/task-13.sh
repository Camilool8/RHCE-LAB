#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 13 — vault rekey: new password 'ansible', file remains encrypted
TASK_NUM=13
TASK_TITLE="ansible-vault rekey — new password 'ansible'"
TASK_POINTS=10
VAULT_PW_REKEYED="${VAULT_PW_REKEYED:-ansible}"

task_verify() {
    local vault="$ANSIBLE_DIR/vault.yml"
    score_check 1 "vault.yml exists" test -f "$vault"
    score_check 2 "vault.yml still encrypted" \
        bash -c "head -1 '$vault' | grep -q '^\$ANSIBLE_VAULT'"

    # New password 'ansible' must decrypt the vault and yield the original keys.
    local pwf; pwf=$(mktemp); printf '%s' "$VAULT_PW_REKEYED" >"$pwf"
    local decrypted=""
    decrypted=$( ( cd "$ANSIBLE_DIR" && ansible-vault view vault.yml --vault-password-file="$pwf" ) 2>/dev/null || true )
    rm -f "$pwf"

    SCORE_MAX=$((SCORE_MAX + 4))
    if grep -qE '^\s*dev_pass:\s*redhat\s*$' <<<"$decrypted" \
        && grep -qE '^\s*mgr_pass:\s*linux\s*$' <<<"$decrypted"; then
        SCORE_POINTS=$((SCORE_POINTS + 4))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+4) vault decrypts with new password and content preserved")
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/4) vault must decrypt with password '${VAULT_PW_REKEYED}' and contain dev_pass+mgr_pass")
    fi

    # Negative check: the *original* password must NOT decrypt anymore.
    SCORE_MAX=$((SCORE_MAX + 3))
    local pwf2; pwf2=$(mktemp); printf '%s' "${VAULT_PW_INITIAL:-rh294lab}" >"$pwf2"
    if ! ( cd "$ANSIBLE_DIR" && ansible-vault view vault.yml --vault-password-file="$pwf2" ) >/dev/null 2>&1; then
        SCORE_POINTS=$((SCORE_POINTS + 3))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+3) original password rejected (rekey was real)")
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/3) original password should no longer decrypt the vault")
    fi
    rm -f "$pwf2"
}
