#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 16 — lvm.yml: LV 'data' in VG 'research', 1200 MiB (or 800 MiB fallback), ext4, NOT mounted
TASK_NUM=16
TASK_TITLE="lvm.yml — research/data LV, ext4, unmounted"
TASK_POINTS=20

task_apply() {
    [[ -f "$ANSIBLE_DIR/lvm.yml" ]] || { log_warn "lvm.yml missing"; return 1; }
    playbook_idempotent lvm.yml
}

task_verify() {
    score_check 1 "lvm.yml exists" test -f "$ANSIBLE_DIR/lvm.yml"

    local node
    for node in "${ALL_NODES[@]}"; do
        score_check 2 "${node}: VG 'research' exists" node_sudo "$node" "vgs --noheadings -o vg_name research"
        score_check 2 "${node}: LV 'research/data' exists" \
            node_sudo "$node" "lvs --noheadings research/data"
        # Size must be exactly 1200 MiB or fallback 800 MiB.
        score_check 2 "${node}: LV size is 1200m or 800m" \
            node_sudo "$node" \
            "lvs --noheadings --units m -o lv_size /dev/research/data 2>/dev/null \
              | awk '{gsub(/m\$/,\"\",\$1); v=int(\$1+0.5); exit !(v==1200 || v==800)}'"
        score_check 2 "${node}: filesystem is ext4 on /dev/research/data" \
            node_sudo "$node" "blkid /dev/research/data | grep -qi 'TYPE=\"ext4\"'"
        # MUST NOT be mounted, no fstab entry.
        score_check 1 "${node}: data LV is NOT mounted" \
            node_sudo "$node" "! findmnt /dev/research/data && ! grep -qE '/dev/research/data|research-data' /etc/fstab"
    done
}

task_reboot_survival() { task_verify; }
