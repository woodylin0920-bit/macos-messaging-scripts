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
  sleep 2
  osascript -e 'tell application "WhatsApp" to activate' >/dev/null 2>&1
  sleep 0.3
  wa_pin_window
  sleep 0.6
else
  wa_log "No phone for $CONTACT, using search + AX pick"
  wa_activate
  wa_search "$CONTACT"
  # FAIL CLOSED: reading the wrong chat leaks someone else's messages. If the name
  # isn't a unique match, abort rather than reading row 1. (URL-scheme path above
  # is unambiguous.)
  if ! wa_pick_chat_by_name "$CONTACT"; then
    wa_log "⚠️  '$CONTACT' 不是唯一相符(撞名/找不到)。為避免讀到錯的人的訊息,中止。請用更精確的名字或已知號碼。"
    exit 1
  fi
fi
sleep 0.5

osascript "$SCRIPT_DIR/wa_read.scpt" "$COUNT"

# Close the chat (one Esc → splash) so WhatsApp isn't left sitting in the
# conversation marking later incoming messages read.
wa_escape
