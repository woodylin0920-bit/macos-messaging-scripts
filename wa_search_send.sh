#!/bin/bash
# wa_search_send.sh <contact_name> <message> <verified_row_y>
# Send a WhatsApp message via search flow.
# Requires a VERIFIED row Y coordinate (from vision analysis).
#
# This script does NOT guess which row to click — the caller must
# provide the correct Y coordinate after vision verification.
#
# Usage from agent:
#   1. source wa_helpers.sh && wa_activate && wa_search "Name"
#   2. screencapture → vision → identify correct row Y
#   3. wa_search_send.sh "Name" "Message" <verified_y>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wa_helpers.sh"

CONTACT="${1:?Usage: wa_search_send.sh <contact_name> <message> <verified_row_y>}"
MESSAGE="${2:?Usage: wa_search_send.sh <contact_name> <message> <verified_row_y>}"
VERIFIED_Y="${3:?Usage: wa_search_send.sh <contact_name> <message> <verified_row_y>}"

wa_log "Sending to $CONTACT at verified y=$VERIFIED_Y"

# Click the verified row
cliclick c:197,"$VERIFIED_Y"
sleep 1.5

# Click input field
cliclick c:${WA_INPUT_X},${WA_INPUT_Y}
sleep 0.3

# Paste message
printf '%s' "$MESSAGE" | pbcopy
osascript -e '
tell application "System Events"
  tell process "WhatsApp"
    keystroke "v" using command down
  end tell
end tell
'
sleep 0.3

# Send
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
sleep 1

# Escape back to chat list
wa_escape

wa_log "✅ Message sent to $CONTACT"
