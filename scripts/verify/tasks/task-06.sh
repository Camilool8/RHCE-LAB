#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 6 — Galaxy roles via requirements.yml, installed under $ANSIBLE_DIR/roles
TASK_NUM=06
TASK_TITLE="ansible-galaxy roles: zabbix, security, squid"
TASK_POINTS=10

task_apply() {
    local req="$ANSIBLE_DIR/roles/requirements.yml"
    [[ -f "$req" ]] || { log_warn "roles/requirements.yml missing"; return 1; }
    ( cd "$ANSIBLE_DIR" && ansible-galaxy role install -p roles/ -r roles/requirements.yml ) \
        >/tmp/verify-apply-galaxy.log 2>&1
}

task_verify() {
    local req="$ANSIBLE_DIR/roles/requirements.yml"
    score_check 1 "requirements.yml exists"             test -f "$req"
    score_check 1 "requirements.yml references zabbix-zabbix tarball"  grep -q 'zabbix-zabbix' "$req"
    score_check 1 "requirements.yml references openafs tarball"        grep -q 'openafs' "$req"
    score_check 1 "requirements.yml references mafalb-squid tarball"   grep -q 'mafalb-squid' "$req"
    score_check 2 "role 'zabbix' installed"     test -d "$ANSIBLE_DIR/roles/zabbix"
    score_check 2 "role 'security' installed"   test -d "$ANSIBLE_DIR/roles/security"
    score_check 2 "role 'squid' installed"      test -d "$ANSIBLE_DIR/roles/squid"
}
