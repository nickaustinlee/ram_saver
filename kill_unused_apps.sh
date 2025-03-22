#!/bin/bash

# Default Configuration
THRESHOLD_MINUTES=120  # Default minimum idle time before considering an app
MEMORY_THRESHOLD_MB=200  # Default memory threshold in MB
EXCLUDE_APPS_FILE="exclude_apps.txt"
DRY_RUN=false  # Default: actually kill apps
TOTAL_RAM_FREED=0  # Track total RAM freed up

# Temporary file to store freed memory data
TMP_RAM_FILE=$(mktemp)

# Parse command-line arguments
for arg in "$@"; do
    case $arg in
        --noop)
            DRY_RUN=true
            echo "[NO-OP MODE] Running in dry-run mode: No applications will be killed."
            ;;
        --memory=*)
            MEMORY_THRESHOLD_MB="${arg#*=}"
            if ! [[ "$MEMORY_THRESHOLD_MB" =~ ^[0-9]+$ ]]; then
                echo "Error: Invalid memory threshold. Please specify a number in MB."
                exit 1
            fi
            echo "Memory threshold set to ${MEMORY_THRESHOLD_MB}MB"
            ;;
        --elapsed=*)
            THRESHOLD_MINUTES="${arg#*=}"
            if ! [[ "$THRESHOLD_MINUTES" =~ ^[0-9]+$ ]]; then
                echo "Error: Invalid elapsed minutes. Please specify a number."
                exit 1
            fi
            echo "Elapsed time threshold set to ${THRESHOLD_MINUTES} minutes"
            ;;
        *)
            echo "Usage: $0 [--noop] [--memory=MB] [--elapsed=MINUTES]"
            exit 1
            ;;
    esac
done

# Function to load excluded apps from a text file
load_excluded_apps_txt() {
    if [[ -f "$EXCLUDE_APPS_FILE" ]]; then
        EXCLUDE_APPS=()
        while IFS= read -r line; do
            EXCLUDE_APPS+=("$line")
        done < "$EXCLUDE_APPS_FILE"
    else
        EXCLUDE_APPS=()
    fi
}

# Function to load excluded apps from a JSON file
load_excluded_apps_json() {
    if [[ -f "$EXCLUDE_APPS_FILE" ]]; then
        EXCLUDE_APPS=($(jq -r '.excluded_apps[]' "$EXCLUDE_APPS_FILE"))
    else
        EXCLUDE_APPS=()
    fi
}

# Determine file format and load exclusions
if [[ "$EXCLUDE_APPS_FILE" == *.json ]]; then
    load_excluded_apps_json
else
    load_excluded_apps_txt
fi

# Get the currently active (foreground) application
ACTIVE_APP=$(osascript -e 'tell application "System Events" to get name of (processes whose frontmost is true)')
ACTIVE_APP=$(echo "$ACTIVE_APP" | sed 's/^ *//;s/ *$//')

# Iterate through GUI applications
osascript -e 'tell application "System Events" to get name of (processes whose background only is false)' | tr ',' '\n' | while read app; do
    app=$(echo "$app" | sed 's/^ *//;s/ *$//')

    # Check if app is in the exclusion list
    if [[ " ${EXCLUDE_APPS[@]} " =~ " ${app} " ]]; then
        continue
    fi

    # Check if the app is the currently active app (foreground)
    if [[ "$app" == "$ACTIVE_APP" ]]; then
        echo "[SKIP] \"$app\" is currently active (foreground). Skipping..."
        continue
    fi

    # Check if the app has any visible windows
    HAS_WINDOWS=$(osascript -e "tell application \"System Events\" to count windows of process \"$app\"" 2>/dev/null)
    if [[ "$HAS_WINDOWS" -gt 0 ]]; then
        echo "[SKIP] \"$app\" has $HAS_WINDOWS visible window(s). Skipping..."
        continue
    fi

    # Get PID
    pid=$(pgrep -x "$app" | head -n1)
    if [ -z "$pid" ]; then
        continue
    fi

    # Get memory usage in MB (RSS column in KB, divided by 1024)
    mem_usage_kb=$(ps -p "$pid" -o rss=)
    mem_usage_mb=$((mem_usage_kb / 1024))

    # Skip processes consuming less than the memory threshold
    if (( mem_usage_mb < MEMORY_THRESHOLD_MB )); then
        continue
    fi

    # Get process start time (MacOS alternative to etimes)
    start_time=$(ps -p "$pid" -o lstart=)
    if [ -z "$start_time" ]; then
        continue
    fi

    # Convert start time to epoch
    start_epoch=$(date -j -f "%a %b %d %T %Y" "$start_time" +"%s" 2>/dev/null)
    if [ -z "$start_epoch" ]; then
        continue
    fi

    # Get current time in epoch
    current_epoch=$(date +"%s")

    # Calculate elapsed time in minutes
    elapsed_minutes=$(( (current_epoch - start_epoch) / 60 ))

    # If idle longer than threshold and using too much RAM, take action
    if (( elapsed_minutes >= THRESHOLD_MINUTES )); then
        if [[ "$DRY_RUN" == true ]]; then
            echo "[NO-OP] Would kill \"$app\" (PID: $pid), running for $elapsed_minutes minutes, using ${mem_usage_mb}MB RAM"
        else
            echo "Killing \"$app\" (PID: $pid), running for $elapsed_minutes minutes, using ${mem_usage_mb}MB RAM"
            kill "$pid"
            echo "$mem_usage_mb" >> "$TMP_RAM_FILE"
        fi
    fi
done

# Sum up total RAM freed
if [[ "$DRY_RUN" == false ]]; then
    if [[ -s "$TMP_RAM_FILE" ]]; then
        TOTAL_RAM_FREED=$(awk '{sum+=$1} END {print sum}' "$TMP_RAM_FILE")
        echo "✅ Total RAM freed: ${TOTAL_RAM_FREED}MB"
    else
        echo "✅ No applications were killed. Total RAM freed: 0MB"
    fi
else
    echo "🛑 [NO-OP] This run was a dry-run. No RAM was actually freed."
fi

# Clean up temporary file
rm -f "$TMP_RAM_FILE"

