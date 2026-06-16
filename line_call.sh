#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# line_call.sh — LINE voice/video call (vision-gated, NOT blind no_agent)
# Usage: line_call.sh <contact_name> [hang_up_seconds] [result_index] [voice|video]
#
#   line_call.sh "Alice" 3            # voice call row1, hang up after 3s
#   line_call.sh "Alice" 3 2 video    # video call row2, hang up after 3s
#
# ⚠️ LINE has NO URL scheme — search-based, always carries wrong-person risk.
#    result_index must come from HUMAN/VISION confirmation. Not cron-safe blind.

source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"

CONTACT="$1"
HANGUP_AFTER="${2:-}"
RESULT_INDEX="${3:-1}"
CALL_TYPE="${4:-voice}"

if [ -z "$CONTACT" ]; then
  echo "Usage: line_call.sh <contact_name> [hang_up_seconds] [result_index] [voice|video]"
  exit 1
fi

# 1. Activate + pin
line_activate

# 2. Search
line_search "$CONTACT"

# 3. Pre-verify screenshot
BEFORE=$(line_shot before)
echo "MEDIA:$BEFORE"
line_log "before-screenshot: $BEFORE (confirm row $RESULT_INDEX is the right person)"

# 4. Open chat
line_click_result "$RESULT_INDEX"

# 5. Start call
line_start_call "$CALL_TYPE"
CLICK_Y=$((LINE_RESULT_ROW1_Y + (RESULT_INDEX - 1) * LINE_ROW_H))
echo "📞 Calling $CONTACT ($CALL_TYPE, result #$RESULT_INDEX, y=$CLICK_Y)..."

# 6. Auto-hangup if requested
if [ -n "$HANGUP_AFTER" ]; then
  sleep "$HANGUP_AFTER"
  line_hangup
  echo "📵 Hung up after ${HANGUP_AFTER}s (Escape→Enter)"
fi

# 7. Post-verify
AFTER=$(line_shot after)
echo "MEDIA:$AFTER"
line_log "after-screenshot: $AFTER — verify the call actually connected/logged"

# 8. Hide LINE
line_hide
echo "✅ Done. Verify via $AFTER (never trust exit 0)."
