#!/bin/bash

# Script to get implementation address from a proxy contract
# Usage: ./scripts/get_implementation_address.sh [proxy_address] [rpc_url]

if [ $# -lt 2 ]; then
    echo "Usage: $0 [proxy_address] [rpc_url]"
    exit 1
fi

PROXY_ADDRESS=$1
RPC_URL=$2

# The ERC1967 implementation slot is at keccak256("eip1967.proxy.implementation") - 1
IMPL_SLOT="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

# Get the storage at the implementation slot
STORAGE_VALUE=$(cast storage "$PROXY_ADDRESS" "$IMPL_SLOT" --rpc-url "$RPC_URL" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$STORAGE_VALUE" ]; then
    echo "Error: Failed to get storage from proxy contract" >&2
    exit 1
fi

# Clean the storage value: remove warnings, whitespace, and extract the hex value
CLEAN_STORAGE=$(echo "$STORAGE_VALUE" | grep "^0x" | tr -d '\n\r' | tail -n1)

# Convert storage value to address (take last 40 hex chars and add 0x prefix)
IMPLEMENTATION_ADDRESS="0x$(echo "$CLEAN_STORAGE" | sed 's/^0x//' | tail -c 41)"

# Verify this is a valid contract
CODE=$(cast code "$IMPLEMENTATION_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null)
if [ -z "$CODE" ] || [ "$CODE" = "0x" ]; then
    echo "Error: No code found at implementation address - this might not be a valid contract" >&2
    exit 1
fi

echo "$IMPLEMENTATION_ADDRESS"
