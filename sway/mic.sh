#!/bin/bash

mic_status=$(/usr/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@)

volume=$(echo "$mic_status" | awk '{print int($2 * 100)}')

if [[ $mic_status == *"MUTED"* ]]; then
    echo "🎙 off"
    exit 0
fi

if [ "$volume" -ge 70 ]; then
    echo "🎙 🔊 $volume%"
elif [ "$volume" -ge 30 ]; then
    echo "🎙 🎤 $volume%"
else
    echo "🎙 🔈 $volume%"
fi

