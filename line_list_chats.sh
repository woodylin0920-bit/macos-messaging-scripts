#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# line_list_chats.sh
# Screenshot the LINE chat LIST for a vision model to read. LINE list rows are
# AXUnknown (no text in the Accessibility tree), so — like line_read — this
# returns an image, cropped to the list pane so names stay legible.

source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"

line_activate
sleep 0.3
# Crop to the left chat-list pane only (matches the pinned {0,30} 1440×794 frame)
SHOT="/tmp/line_chats_$(date +%s).png"
screencapture -x -R0,30,340,760 "$SHOT"
echo "MEDIA:$SHOT"
line_log "chat-list screenshot (cropped): $SHOT — read the chat names visually"
echo "✅ LINE chat list captured → $SHOT (vision required; LINE list has no AX text)."
