#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 1 — inventory + ansible.cfg
TASK_NUM=01
TASK_TITLE="Inventory and ansible.cfg"
TASK_POINTS=15

task_verify() {
    local inv="$ANSIBLE_DIR/inventory"
    local cfg="$ANSIBLE_DIR/ansible.cfg"

    score_check 1 "inventory file exists at $inv"   test -f "$inv"
    score_check 1 "ansible.cfg exists at $cfg"      test -f "$cfg"

    # Inventory group structure (parsed via ansible-inventory so we don't
    # care about INI ordering / blank lines).
    local graph
    graph=$( ( cd "$ANSIBLE_DIR" && ansible-inventory --graph 2>/dev/null ) || true )
    score_check 1 "group [dev] contains node1"        grep -q '@dev:' <<<"$graph"
    score_check 1 "node1 is in dev"                   grep -Pzq '(?s)@dev:.*?node1' <<<"$graph"
    score_check 1 "node2 is in test"                  grep -Pzq '(?s)@test:.*?node2' <<<"$graph"
    score_check 1 "node3 is in prod"                  grep -Pzq '(?s)@prod:.*?node3' <<<"$graph"
    score_check 1 "node4 is in prod"                  grep -Pzq '(?s)@prod:.*?node4' <<<"$graph"
    score_check 1 "node5 is in balancers"             grep -Pzq '(?s)@balancers:.*?node5' <<<"$graph"
    score_check 2 "webservers has prod as child"      grep -Pzq '(?s)@webservers:.*?@prod' <<<"$graph"

    # ansible.cfg keys (parse minimally — grep the file).
    score_check 1 "ansible.cfg: inventory configured"     grep -Eq '^\s*inventory\s*=' "$cfg"
    score_check 1 "ansible.cfg: collections path set"     grep -Eq '^\s*collections_path\s*=.*mycollection' "$cfg"
    score_check 1 "ansible.cfg: roles_path set"           grep -Eq '^\s*roles_path\s*=.*roles' "$cfg"

    # End-to-end: 'ansible all -m ping' with no flags must succeed (proves
    # remote_user + key + inventory + host_key_checking are all wired up).
    score_check 3 "ansible all -m ping works with no extra flags" \
        bash -c "cd '$ANSIBLE_DIR' && ansible all -m ping"
}
