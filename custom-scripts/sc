#!/bin/bash

# Source folder where screenshots are saved
SRC="$HOME/Pictures"

# Destination folder in Obsidian
DST="$HOME/Documents/Notes/Attachments/Screenshot"

# Ensure destination exists
mkdir -p "$DST"

# Find the latest screenshot in Pictures
LATEST_FILE=$(ls -t "$SRC"/*.{png,jpg,jpeg} 2>/dev/null | head -n 1)

if [ -n "$LATEST_FILE" ]; then
    # Generate timestamp for unique filename
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    EXT="${LATEST_FILE##*.}"
    NEW_FILE="$DST/Screenshot_$TIMESTAMP.$EXT"
    
    # Copy the file
    cp "$LATEST_FILE" "$NEW_FILE"
    
    # Output Markdown link
    REL_PATH="Attachments/Screenshot/$(basename "$NEW_FILE")"
    echo "![Screenshot]($REL_PATH)"
else
    echo "No screenshots found in $SRC"
fi

