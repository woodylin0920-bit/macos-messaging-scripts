#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# wa_call.sh <contact_name> [hang_up_seconds] [voice|video] [result_index]
# URL scheme opens the correct chat (if phone known), then call dropdown.
# Falls back to search if no phone number.
#
# ⚠️ Search fallback: result order is UNSTABLE — use vision to confirm!

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wa_helpers.sh"

CONTACT="${1:?Usage: wa_call.sh <name> [hangup_sec] [voice|video] [result_idx]}"
HANGUP_AFTER="${2:-}"
CALL_TYPE="${3:-voice}"
RESULT_INDEX="${4:-1}"

PHONE=$(wa_get_phone "$CONTACT" 2>/dev/null || true)

if [[ -n "$PHONE" ]]; then
  # URL scheme → correct chat, no search needed
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
  # Search fallback
  wa_log "No phone for $CONTACT, using search (result #$RESULT_INDEX)"
  wa_activate
  wa_search "$CONTACT"
  wa_click_result "$RESULT_INDEX"
fi

wa_start_call "$CALL_TYPE"
wa_log "📞 Calling $CONTACT ($CALL_TYPE)..."

if [[ -n "$HANGUP_AFTER" ]]; then
  sleep "$HANGUP_AFTER"
  wa_hangup || wa_log "Call may have ended"
  sleep 0.3
fi

wa_escape
wa_log "✅ Done."
