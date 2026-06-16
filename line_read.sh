#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# line_read.sh <contact_name> [result_index]
# Open a LINE chat and screenshot it for the agent to READ VISUALLY.
#
# ⚠️ LINE message content is NOT in the Accessibility tree (all AXUnknown), so
#    unlike WhatsApp there is no text extraction — reading LINE = screenshot +
#    a vision-capable model. Echoes two MEDIA: paths:
#      1) the search result list (vision-confirm the row is the right person)
#      2) the opened chat (read the messages from this image)

source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"

CONTACT="${1:?Usage: line_read.sh <contact_name> [result_index]}"
RESULT_INDEX="${2:-1}"

line_activate
line_search "$CONTACT"

BEFORE=$(line_shot read_before)
echo "MEDIA:$BEFORE"
line_log "search results: $BEFORE — VISION-CONFIRM row $RESULT_INDEX == \"$CONTACT\" before trusting the read"

line_click_result "$RESULT_INDEX"
sleep 1

# Crop to the chat pane ONLY (drop the list / dock / menu bar) so the message
# text stays large and legible for the vision model. Derived from the pinned
# LINE_WIN_* frame so it still aligns if the window is calibrated to a different
# position/size. (~340px is the left chat-list width; ~49px is window chrome.)
CHAT="/tmp/line_read_chat_$(date +%s).png"
LIST_W=340
screencapture -x -R$((LINE_WIN_X + LIST_W)),${LINE_WIN_Y},$((LINE_WIN_W - LIST_W)),$((LINE_WIN_H - 49)) "$CHAT"
echo "MEDIA:$CHAT"
line_log "chat screenshot (cropped to chat pane): $CHAT — read the messages visually"

line_close_chat
line_hide
echo "✅ Opened LINE chat for $CONTACT — read messages from $CHAT (vision required; LINE has no AX text)."
