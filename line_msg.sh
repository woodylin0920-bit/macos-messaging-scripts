#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# line_msg.sh — send a text message via LINE (vision-gated; LINE has no URL scheme)
# Usage: line_msg.sh <contact_name> <message> [result_index]
#
#   line_msg.sh "Woody Lin" "早安" 1
#
# ⚠️ No URL scheme for LINE → search is unavoidable → wrong-person risk. The
#    BEFORE screenshot (echoed MEDIA:) MUST be vision-confirmed (row title ==
#    contact) before the message is typed. Not cron-safe blind.

source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"

CONTACT="$1"
MESSAGE="$2"
RESULT_INDEX="${3:-1}"

if [ -z "$CONTACT" ] || [ -z "$MESSAGE" ]; then
  echo "Usage: line_msg.sh <contact_name> <message> [result_index]"
  exit 1
fi

# 1. Activate + pin window
line_activate

# 2. Search
line_search "$CONTACT"

# 3. Pre-verify screenshot
BEFORE=$(line_shot before)
echo "MEDIA:$BEFORE"
line_log "before-screenshot: $BEFORE (confirm row $RESULT_INDEX title == \"$CONTACT\")"

# 4. Open chat
line_click_result "$RESULT_INDEX"

# 5. Type and send
printf '%s' "$MESSAGE" | pbcopy
line_send_text

# 6. Post-verify
AFTER=$(line_shot after)
echo "MEDIA:$AFTER"
line_log "after-screenshot: $AFTER — verify the green bubble appeared"

# 7. Close the chat room (Esc) so LINE isn't left marking 已讀, then hide
line_close_chat
line_hide
echo "✅ Attempted LINE message to $CONTACT — verify via $AFTER (never trust exit 0)."
