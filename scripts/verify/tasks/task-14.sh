#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 14 — user_list.yml + create_user.yml: 3 users with SHA512 vault-sourced passwords.
TASK_NUM=14
TASK_TITLE="create_user.yml — adam, gabriel, lucifer via vault"
TASK_POINTS=25

task_apply() {
    [[ -f "$ANSIBLE_DIR/create_user.yml" ]] || { log_warn "create_user.yml missing"; return 1; }
    [[ -f "$ANSIBLE_DIR/password.txt"   ]] || { log_warn "password.txt missing";  return 1; }
    # The fixed solution uses password_hash('sha512', <salt>) so we can now
    # require strict idempotency — second run reports changed=0 failed=0.
    playbook_idempotent create_user.yml --vault-password-file=./password.txt
}

task_verify() {
    score_check 1 "user_list.yml exists"  test -f "$ANSIBLE_DIR/user_list.yml"
    score_check 1 "create_user.yml exists" test -f "$ANSIBLE_DIR/create_user.yml"

    # devs (adam, lucifer) on dev + test nodes with group 'devops' + SHA512 hash
    local node u
    for node in "${DEV_NODES[@]}" "${TEST_NODES[@]}"; do
        for u in adam lucifer; do
            score_check 1 "${node}: user ${u} exists"        node_sudo "$node" "id $u"
            score_check 1 "${node}: ${u} in devops group"    node_sudo "$node" "id -nG $u | tr ' ' '\\n' | grep -qx devops"
            score_check 1 "${node}: ${u} password is SHA512" node_sudo "$node" "getent shadow $u | cut -d: -f2 | grep -q '^\\\$6\\\$'"
        done
    done

    # managers (gabriel) on prod nodes with group 'opsmgr' + SHA512
    for node in "${PROD_NODES[@]}"; do
        score_check 1 "${node}: user gabriel exists"          node_sudo "$node" "id gabriel"
        score_check 1 "${node}: gabriel in opsmgr group"      node_sudo "$node" "id -nG gabriel | tr ' ' '\\n' | grep -qx opsmgr"
        score_check 1 "${node}: gabriel password is SHA512"   node_sudo "$node" "getent shadow gabriel | cut -d: -f2 | grep -q '^\\\$6\\\$'"
    done

    # UID checks (3000/3001/3002 on first node that should have each)
    score_check 2 "node1: adam UID is 3000"      node_sudo node1 "id -u adam | grep -qx 3000"
    score_check 2 "node3: gabriel UID is 3001"   node_sudo node3 "id -u gabriel | grep -qx 3001"
    score_check 2 "node1: lucifer UID is 3002"   node_sudo node1 "id -u lucifer | grep -qx 3002"

    # Negative: balancers (node5) should have no users
    SCORE_MAX=$((SCORE_MAX + 2))
    if ! node_sudo node5 "id adam || id gabriel || id lucifer" >/dev/null 2>&1; then
        SCORE_POINTS=$((SCORE_POINTS + 2))
        SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+2) node5: none of the users were created (correctly excluded)")
    else
        SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/2) node5 (balancers) must not have these users")
    fi
}

task_reboot_survival() { task_verify; }
