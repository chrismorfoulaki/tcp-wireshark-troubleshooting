#!/usr/bin/env bash
set -Eeuo pipefail

CLIENT_NS="tcp-lab-client"
SERVER_NS="tcp-lab-server"
CLIENT_IF="veth-labclient"
SERVER_IF="veth-labserver"
CLIENT_IP="192.0.2.10/24"
SERVER_IP="192.0.2.20/24"

CREATING=0

cleanup_on_error() {
    rc=$?
    if [[ "$CREATING" == "1" && "$rc" -ne 0 ]]; then
        echo "Setup failed. Removing namespaces created by this run..."
        ip netns del "$CLIENT_NS" 2>/dev/null || true
        ip netns del "$SERVER_NS" 2>/dev/null || true
    fi
}
trap cleanup_on_error EXIT

if [[ "$EUID" -ne 0 ]]; then
    echo "Run this script with sudo: sudo ./scripts/setup_lab.sh" >&2
    exit 1
fi

namespace_exists() {
    ip netns list | awk -v name="$1" '$1 == name { found=1 } END { exit !found }'
}

interface_configured() {
    local ns="$1"
    local iface="$2"
    local address="$3"

    ip -n "$ns" link show dev "$iface" |
        awk '/<[^>]*UP[^>]*>/ { found=1 } END { exit !found }' &&
    ip -n "$ns" -o -4 addr show dev "$iface" |
        awk -v expected="$address" '$4 == expected { found=1 } END { exit !found }'
}

CLIENT_EXISTS=0
SERVER_EXISTS=0

if namespace_exists "$CLIENT_NS"; then
    CLIENT_EXISTS=1
fi

if namespace_exists "$SERVER_NS"; then
    SERVER_EXISTS=1
fi

# If both namespaces exist, validate them without modifying the lab.
if [[ "$CLIENT_EXISTS" == "1" && "$SERVER_EXISTS" == "1" ]]; then
    if interface_configured "$CLIENT_NS" "$CLIENT_IF" "$CLIENT_IP" &&
       interface_configured "$SERVER_NS" "$SERVER_IF" "$SERVER_IP"; then
        echo "Both namespaces and their interfaces are configured correctly."
        echo "No changes made."
        exit 0
    else
        echo "Existing namespaces do not match the expected lab configuration." >&2
        echo "No changes made. Inspect the interfaces before proceeding." >&2
        exit 1
    fi
fi

# Never overwrite a partial existing setup automatically.
if [[ "$CLIENT_EXISTS" == "1" || "$SERVER_EXISTS" == "1" ]]; then
    echo "Only one lab namespace exists. Refusing to modify a partial setup." >&2
    exit 1
fi

# Avoid colliding with interfaces in the main network namespace.
if ip link show dev "$CLIENT_IF" >/dev/null 2>&1 ||
   ip link show dev "$SERVER_IF" >/dev/null 2>&1; then
    echo "A lab interface name already exists in the main namespace." >&2
    echo "No changes made. Inspect the existing interfaces first." >&2
    exit 1
fi

CREATING=1

echo "Creating client and server namespaces..."
ip netns add "$CLIENT_NS"
ip netns add "$SERVER_NS"

echo "Creating virtual Ethernet pair..."
ip link add "$CLIENT_IF" type veth peer name "$SERVER_IF"
ip link set "$CLIENT_IF" netns "$CLIENT_NS"
ip link set "$SERVER_IF" netns "$SERVER_NS"

echo "Assigning IP addresses..."
ip -n "$CLIENT_NS" addr add "$CLIENT_IP" dev "$CLIENT_IF"
ip -n "$SERVER_NS" addr add "$SERVER_IP" dev "$SERVER_IF"

echo "Bringing interfaces up..."
ip -n "$CLIENT_NS" link set lo up
ip -n "$CLIENT_NS" link set "$CLIENT_IF" up
ip -n "$SERVER_NS" link set lo up
ip -n "$SERVER_NS" link set "$SERVER_IF" up

CREATING=0

echo
echo "Lab interfaces configured."
echo "Client: $CLIENT_NS — $CLIENT_IP"
echo "Server: $SERVER_NS — $SERVER_IP"
echo
echo "Check connectivity with:"
echo "sudo ip netns exec $CLIENT_NS ping -c 3 192.0.2.20"
