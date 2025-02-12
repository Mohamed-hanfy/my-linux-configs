#!/bin/sh

# Times the screen off and puts it to background
swayidle \
    timeout 10 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' &

IDLE_PID=$!

# Locks the screen immediately
swaylock -c 000000  # or 550000 if you want dark red

# Kills the background idle timer
kill $IDLE_PID 2>/dev/null
