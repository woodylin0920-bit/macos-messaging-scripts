#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# line_list_chats.sh
# Screenshot the LINE chat LIST for a vision model to read. LINE list rows are
# AXUnknown (no text in the Accessibility tree), so — like line_read — this
# returns an image, cropped to the list pane so names stay legible.

source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"

line_activate
# Clear any leftover search query/overlay (LINE persists it across sessions),
# otherwise the screenshot would show filtered results, not the recent chat list.
line_close_chat
sleep 0.3
# Crop the left chat-list pane, derived from the pinned LINE_WIN_* frame so it
# tracks a calibrated window. Width 400 so right-aligned timestamps aren't clipped.
SHOT="/tmp/line_chats_$(date +%s).png"
screencapture -x -R${LINE_WIN_X},${LINE_WIN_Y},400,$((LINE_WIN_H - 34)) "$SHOT"
echo "MEDIA:$SHOT"
line_log "chat-list screenshot (cropped): $SHOT — read the chat names visually"
echo "✅ LINE chat list captured → $SHOT (vision required; LINE list has no AX text)."
