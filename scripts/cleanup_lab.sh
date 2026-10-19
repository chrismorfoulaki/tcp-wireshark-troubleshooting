#!/usr/bin/env bash
set -Eeuo pipefail

CLIENT_NS="tcp-lab-client"
SERVER_NS="tcp-lab-server"
DRY_RUN=0

usage() {
    echo "Usage: sudo $0 [--dry-run]"
}

if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo: sudo ./scripts/cleanup_lab.sh" >&2
    exit 1
fi

if [[ $# -gt 1 ]]; then
    usage
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=1
    else
        usage
        exit 1
    fi
fi

namespace_exists() {
    ip netns list |
        awk -v name="$1" '$1 == name { found=1 } END { exit !found }'
}

# Refuse cleanup if any process is still using a lab namespace.
BUSY=0

for ns in "$CLIENT_NS" "$SERVER_NS"; do
    if namespace_exists "$ns"; then
        PIDS="$(ip netns pids "$ns" 2>/dev/null || true)"

        if [[ -n "$PIDS" ]]; then
            echo "Cannot clean up: processes are still using $ns:"
            for pid in $PIDS; do
                ps -p "$pid" -o pid=,comm=,args= || true
            done
            BUSY=1
        fi
    fi
done

if [[ "$BUSY" -eq 1 ]]; then
    echo
    echo "Stop the lab server and any running captures, then retry."
    echo "No namespaces or firewall rules have been changed."
    exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY RUN: no changes will be made."

    for ns in "$CLIENT_NS" "$SERVER_NS"; do
        if namespace_exists "$ns"; then
            echo "Would remove namespace: $ns"
        else
            echo "Namespace not present: $ns"
        fi
    done

    if namespace_exists "$SERVER_NS"; then
        if ip netns exec "$SERVER_NS" \
            iptables -C INPUT -p tcp --dport 8080 -j DROP 2>/dev/null; then
            echo "Would remove the lab TCP/8080 DROP rule."
        else
            echo "No matching TCP/8080 DROP rule found."
        fi
    fi

    exit 0
fi

# Remove matching lab DROP rules inside the server namespace.
# Deleting a namespace also removes its namespace-local firewall state.
if namespace_exists "$SERVER_NS"; then
    while ip netns exec "$SERVER_NS" \
        iptables -C INPUT -p tcp --dport 8080 -j DROP 2>/dev/null; do
        ip netns exec "$SERVER_NS" \
            iptables -D INPUT -p tcp --dport 8080 -j DROP
        echo "Removed a TCP/8080 DROP rule from $SERVER_NS."
    done
fi

# Delete only the two namespaces belonging to this lab.
for ns in "$CLIENT_NS" "$SERVER_NS"; do
    if namespace_exists "$ns"; then
        ip netns del "$ns"
        echo "Removed namespace: $ns"
    else
        echo "Namespace not present: $ns"
    fi
done

echo
echo "Lab cleanup complete."
echo "Packet captures and project files have been preserved."
