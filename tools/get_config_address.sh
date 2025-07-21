#!/bin/bash

# Script to extract contract addresses from config/config.json
# Usage: ./scripts/get_config_address.sh [chain] [field]

CONFIG_FILE="config/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found at $CONFIG_FILE"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 [chain] [field]"
    exit 1
fi

CHAIN=$1
FIELD=$2

# Extract the value using jq
VALUE=$(jq -r ".chains.${CHAIN}.${FIELD} // empty" "$CONFIG_FILE")

if [ -z "$VALUE" ] || [ "$VALUE" = "null" ]; then
    # Try global fields for admin addresses
    GLOBAL_VALUE=$(jq -r ".${FIELD} // empty" "$CONFIG_FILE")
    if [ -n "$GLOBAL_VALUE" ] && [ "$GLOBAL_VALUE" != "null" ]; then
        echo "$GLOBAL_VALUE"
    else
        echo "Error: Field '${FIELD}' not found for chain '${CHAIN}'"
        exit 1
    fi
else
    echo "$VALUE"
fi
