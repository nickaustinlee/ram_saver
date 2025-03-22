#!/bin/bash

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Define high memory pressure thresholds
COMPRESSED_LIMIT_GB=5       # If Compressed Memory > 5GB, trigger high pressure
SWAP_LIMIT_MB=2000          # If Swap > 2GB, trigger high pressure
#FREE_MEM_LIMIT_MB=500       # If Free Memory < 500MB, trigger high pressure

# Get full memory stats from `top`
PHYS_MEM_STATS=$(top -l 1 | grep "PhysMem")

# Function to convert MB to GB if needed
convert_mb_to_gb() {
    local value=$(echo "$1" | sed 's/M//;s/G//')
    local unit=$(echo "$1" | grep -o '[MG]')
    if [[ "$unit" == "M" ]]; then
        # Convert MB to GB
        echo "scale=2; $value / 1024" | bc
    else
        echo "$value"
    fi
}

# Extract values
USED_MEM_RAW=$(echo "$PHYS_MEM_STATS" | grep -oE '([0-9]+G) used' | awk '{print $1}' | sed 's/G//')
WIRED_MEM_RAW=$(echo "$PHYS_MEM_STATS" | grep -oE '([0-9]+M) wired' | awk '{print $1}')
COMPRESSED_MEM_RAW=$(echo "$PHYS_MEM_STATS" | grep -oE '([0-9]+M) compressor' | awk '{print $1}')
FREE_MEM_RAW=$(echo "$PHYS_MEM_STATS" | grep -oE '([0-9]+M) unused' | awk '{print $1}')

# Convert MB values to GB where necessary
WIRED_MEM_GB=$(convert_mb_to_gb "$WIRED_MEM_RAW")
COMPRESSED_MEM_GB=$(convert_mb_to_gb "$COMPRESSED_MEM_RAW")
FREE_MEM_MB=$(echo "$FREE_MEM_RAW" | sed 's/M//')

# Compute App Memory: (Used - Wired - Compressed)
APP_MEM_GB=$(echo "$USED_MEM_RAW - $WIRED_MEM_GB - $COMPRESSED_MEM_GB" | bc)

# Get swap usage
SWAP_USED_MB=$(sysctl vm.swapusage | awk '{print $7}' | sed 's/M//')
SWAP_USED_MB=${SWAP_USED_MB:-0}  # Ensure a default value

# Print Debug Information
echo "🔍 Memory Stats: Used: ${USED_MEM_RAW}GB | App: ${APP_MEM_GB}GB | Wired: ${WIRED_MEM_GB}GB | Compressed: ${COMPRESSED_MEM_GB}GB | Free: ${FREE_MEM_MB}MB | Swap: ${SWAP_USED_MB}MB"

# Determine memory pressure state
if (( $(echo "$SWAP_USED_MB > $SWAP_LIMIT_MB" | bc -l) )) || \
   (( $(echo "$COMPRESSED_MEM_GB > $COMPRESSED_LIMIT_GB" | bc -l) )); then
    echo "⚠️ HIGH MEMORY PRESSURE! Consider freeing RAM."
    exit 1
else
    echo "✅ Memory pressure is LOW. No action needed."
    exit 0
fi

