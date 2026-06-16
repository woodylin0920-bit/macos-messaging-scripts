#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# wa_msg.sh <contact_name> <message> [result_index]
# URL scheme preferred (if phone known), search fallback.
#
# ⚠️ Search fallback: result order is UNSTABLE — use vision to confirm!

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wa_helpers.sh"

CONTACT="${1:?Usage: wa_msg.sh <name> <message> [result_idx]}"
MESSAGE="${2:?Usage: wa_msg.sh <name> <message> [result_idx]}"
RESULT_INDEX="${3:-1}"

PHONE=$(wa_get_phone "$CONTACT" 2>/dev/null || true)

if [[ -n "$PHONE" ]]; then
  wa_log "Opening $CONTACT via URL scheme ($PHONE)"
  open "whatsapp://send?phone=$PHONE"
  sleep 3
  osascript << 'EOF'
tell application "WhatsApp" to activate
delay 0.3
tell application "System Events"
  tell process "WhatsApp"
    set frontmost to true
    tell window 1
      set position to {0, 25}
      set size to {1440, 875}
    end tell
  end tell
end tell
EOF
  sleep 0.6
else
  wa_log "No phone for $CONTACT, using search (result #$RESULT_INDEX)"
  wa_activate
  wa_search "$CONTACT"
  wa_click_result "$RESULT_INDEX"
fi

wa_send_message "$MESSAGE"
wa_escape
wa_log "✅ Message sent to $CONTACT"
