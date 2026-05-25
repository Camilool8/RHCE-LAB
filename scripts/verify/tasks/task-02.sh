#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 2 — yum_repository playbook
TASK_NUM=02
TASK_TITLE="yum-repo.yml — BaseOS + AppStream repos on all nodes"
TASK_POINTS=15

task_apply() {
    [[ -f "$ANSIBLE_DIR/yum-repo.yml" ]] || { log_warn "yum-repo.yml missing"; return 1; }
    playbook_idempotent yum-repo.yml
    return $?
}

_node_has_repo() {
    local node="$1" name="$2"
    node_sudo "$node" \
        "test -f /etc/yum.repos.d/${name}.repo && grep -q '^name=${name}' /etc/yum.repos.d/${name}.repo 2>/dev/null || \
         grep -q '^\[${name}\]' /etc/yum.repos.d/*.repo 2>/dev/null"
}
_node_repo_has_kv() {
    local node="$1" repo="$2" key="$3" value="$4"
    node_sudo "$node" \
        "awk -v r=\"[${repo}]\" -v k=\"^${key}=${value}\\\$\" '\$0==r{f=1;next} /^\\[/{f=0} f && \$0~k{found=1} END{exit !found}' /etc/yum.repos.d/*.repo"
}

task_verify() {
    score_check 1 "yum-repo.yml exists" test -f "$ANSIBLE_DIR/yum-repo.yml"

    local node
    for node in "${ALL_NODES[@]}"; do
        score_check 1 "${node}: BaseOS repo file present"      _node_has_repo "$node" BaseOS
        score_check 1 "${node}: AppStream repo file present"   _node_has_repo "$node" AppStream
    done
    # Spot-check a single node for required keys (rest checked structurally above).
    local n="${ALL_NODES[0]}"
    score_check 1 "${n}: BaseOS baseurl is file:///mnt/BaseOS/"  _node_repo_has_kv "$n" BaseOS    baseurl    'file:///mnt/BaseOS/'
    score_check 1 "${n}: AppStream baseurl correct"             _node_repo_has_kv "$n" AppStream baseurl    'file:///mnt/AppStream/'
    score_check 1 "${n}: BaseOS gpgcheck=1"                     _node_repo_has_kv "$n" BaseOS    gpgcheck   '1'
    score_check 1 "${n}: BaseOS enabled=0"                      _node_repo_has_kv "$n" BaseOS    enabled    '0'
}

task_reboot_survival() { task_verify; }
