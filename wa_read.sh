#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# wa_read.sh <contact_name> [count]
# Open the chat (URL scheme if phone known, else AX-pick by name) and print the
# last [count] messages as TEXT (read from the Accessibility tree — no vision).
#
#   wa_read.sh "Alice"        # last 12 messages
#   wa_read.sh "Alice" 20     # last 20

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wa_helpers.sh"

CONTACT="${1:?Usage: wa_read.sh <name> [count]}"
COUNT="${2:-12}"

PHONE=$(wa_get_phone "$CONTACT" 2>/dev/null || true)

if [[ -n "$PHONE" ]]; then
  wa_log "Opening $CONTACT via URL scheme ($PHONE)"
  open "whatsapp://send?phone=$PHONE"
  sleep 3
  osascript << 'EOF' >/dev/null 2>&1
tell application "WhatsApp" to activate
delay 0.3
tell application "System Events" to tell process "WhatsApp"
  set frontmost to true
  tell window 1 to set {position, size} to {{0, 25}, {1440, 875}}
end tell
EOF
  sleep 0.6
else
  wa_log "No phone for $CONTACT, using search + AX pick"
  wa_activate
  wa_search "$CONTACT"
  if ! wa_pick_chat_by_name "$CONTACT"; then
    wa_log "AX pick failed/ambiguous — VISION-CONFIRM the chat before trusting output"
    wa_click_result 1
  fi
fi
sleep 0.5

osascript "$SCRIPT_DIR/wa_read.scpt" "$COUNT"
