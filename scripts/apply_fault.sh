#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_NS="tcp-lab-server"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo: sudo ./scripts/apply_fault.sh" >&2
    exit 1
fi

if ! ip netns list | awk -v name="$SERVER_NS" \
    '$1 == name { found=1 } END { exit !found }'; then
    echo "Error: namespace $SERVER_NS does not exist." >&2
    exit 1
fi

RULE=(-p tcp --dport 8080 -j DROP)

if ip netns exec "$SERVER_NS" iptables -C INPUT "${RULE[@]}" 2>/dev/null; then
    echo "The TCP/8080 DROP rule already exists. No changes made."
    exit 0
fi

ip netns exec "$SERVER_NS" iptables -I INPUT 1 "${RULE[@]}"

echo "Added the TCP/8080 DROP rule inside $SERVER_NS."
echo "Verify it with:"
echo "sudo ip netns exec $SERVER_NS iptables -L INPUT -n -v --line-numbers"
