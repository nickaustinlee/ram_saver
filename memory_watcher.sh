#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define paths relative to this script's location
MEMORY_MONITOR="$SCRIPT_DIR/memory_monitor.sh"
KILL_APPS="$SCRIPT_DIR/kill_unused_apps.sh"
LOG_FILE="$SCRIPT_DIR/memory_monitor.log"
MAX_LOG_SIZE=10485760  # 10MB in bytes

# Function to rotate logs if they exceed the limit
rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        # Use macOS-compatible `stat`
        LOG_SIZE=$(stat -f%z "$LOG_FILE")  # Get file size in bytes

        if (( LOG_SIZE > MAX_LOG_SIZE )); then
            echo "$(date "+%Y-%m-%d %H:%M:%S") | 🔄 Log file exceeded 10MB, rotating..." >> "$LOG_FILE"
            
            mv "$LOG_FILE" "$LOG_FILE.old"
            truncate -s 0 "$LOG_FILE"  # Clear the current log
        fi
    fi
}

# Rotate log if needed
rotate_log

# Run memory monitoring script
$MEMORY_MONITOR
EXIT_CODE=$?  # Capture the exit code of memory_monitor.sh

# Log the event with a timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

if [[ $EXIT_CODE -eq 1 ]]; then
    echo "$TIMESTAMP | ⚠️ High memory pressure detected! Running app killer..." >> "$LOG_FILE"

    # Run the kill script with specific thresholds
    $KILL_APPS --memory=100 --elapsed=60 >> "$LOG_FILE" 2>&1

    echo "$TIMESTAMP | ✅ Finished clearing unused apps." >> "$LOG_FILE"
else
    echo "$TIMESTAMP | ✅ Memory is stable. No action taken." >> "$LOG_FILE"
fi

