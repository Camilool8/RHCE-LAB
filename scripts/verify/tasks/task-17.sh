#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
# Task 17 — partition.yml: 1200M primary partition on raw disk; format ext4; on prod, mount /srv.
# IMPORTANT: the task hard-codes /dev/sdb but the lab uses different device names per
# provider (libvirt → /dev/vdb, vmware_desktop → /dev/nvme0n2). We detect the raw disk
# from facts the same way the lab's reference docs recommend, and check whichever name
# is real on this host.
TASK_NUM=17
TASK_TITLE="partition.yml — 1200M primary part + ext4 + /srv mount on prod"
TASK_POINTS=25

task_apply() {
    [[ -f "$ANSIBLE_DIR/partition.yml" ]] || { log_warn "partition.yml missing"; return 1; }
    playbook_idempotent partition.yml
}

_raw_disk_on() {
    # First non-root disk without partitions OR the disk the task names literally.
    node_sudo "$1" "lsblk -d -e 1,7,11 -ndo NAME | grep -v -E '^(sda|vda|nvme0n1)\$' | head -1"
}

task_verify() {
    score_check 1 "partition.yml exists" test -f "$ANSIBLE_DIR/partition.yml"

    local node disk
    for node in "${ALL_NODES[@]}"; do
        disk=$(_raw_disk_on "$node" 2>/dev/null | tr -d '\r\n')
        if [[ -z "$disk" ]]; then
            SCORE_MAX=$((SCORE_MAX + 4))
            SCORE_DETAIL+=("${C_YEL}SKIP${C_OFF} ( 0/4) ${node}: no raw disk found (provider-specific issue)")
            continue
        fi
        score_check 2 "${node}: ${disk}1 partition exists" \
            node_sudo "$node" "lsblk /dev/${disk} | grep -q '${disk}1'"
        score_check 1 "${node}: ${disk}1 size ~1200 MiB or ~800 MiB" \
            node_sudo "$node" \
            "size=\$(lsblk -bno SIZE /dev/${disk}1 2>/dev/null); \
             [ \$((size/1024/1024)) -ge 750 ] && [ \$((size/1024/1024)) -le 1250 ]"
        score_check 1 "${node}: ${disk}1 formatted ext4" \
            node_sudo "$node" "blkid /dev/${disk}1 | grep -qi 'TYPE=\"ext4\"'"
    done

    # On prod nodes only: /srv must be mounted from ${disk}1 AND in fstab
    local pnode
    for pnode in "${PROD_NODES[@]}"; do
        disk=$(_raw_disk_on "$pnode" 2>/dev/null | tr -d '\r\n')
        score_check 2 "${pnode} (prod): /srv is a mountpoint" \
            node_sudo "$pnode" "findmnt /srv"
        score_check 2 "${pnode} (prod): /srv mount source is ${disk:-sdb}1" \
            node_sudo "$pnode" "findmnt -no SOURCE /srv | grep -E '${disk:-sdb}1\$'"
        score_check 2 "${pnode} (prod): /srv mount in /etc/fstab (persistence)" \
            node_sudo "$pnode" "grep -E '\\s/srv\\s' /etc/fstab"
    done

    # Negative: non-prod groups must NOT have /srv mounted from this partition
    local non
    for non in node1 node2 node5; do
        SCORE_MAX=$((SCORE_MAX + 1))
        if ! node_sudo "$non" "findmnt /srv | grep -E 'sdb1|vdb1|nvme0n2p1'" >/dev/null 2>&1; then
            SCORE_POINTS=$((SCORE_POINTS + 1))
            SCORE_DETAIL+=("${C_GRN}PASS${C_OFF} (+1) ${non}: /srv correctly NOT mounted from the data partition")
        else
            SCORE_DETAIL+=("${C_RED}FAIL${C_OFF} ( 0/1) ${non}: /srv should not be mounted from the data partition")
        fi
    done
}

task_reboot_survival() {
    # The critical post-reboot signal: fstab made the prod /srv mount come back.
    task_verify
}
