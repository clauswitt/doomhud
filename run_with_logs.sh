#!/bin/bash

# Run DoomHUD and capture output to a log file
LOG_FILE="$HOME/Desktop/doomhud_debug.log"

echo "Starting DoomHUD with logging to: $LOG_FILE" | tee "$LOG_FILE"
echo "Press Ctrl+C to stop" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# Run the app and log output
./DoomHUD.app/Contents/MacOS/DoomHUD 2>&1 | tee -a "$LOG_FILE"