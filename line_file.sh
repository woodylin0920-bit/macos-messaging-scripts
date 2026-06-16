#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# line_file.sh — send a file via LINE (vision-gated; LINE has no URL scheme)
# Usage: line_file.sh <contact_name> <file_path> [result_index]
#
#   line_file.sh "Alice" /tmp/pic.png        # send to row1
#   line_file.sh "Alice" /tmp/pic.png 2      # send to row2
#
# ⚠️ No URL scheme → search is unavoidable → wrong-person risk. The BEFORE
#    screenshot MUST be vision-confirmed. Not cron-safe blind.

source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"

CONTACT="$1"
FILEPATH="$2"
RESULT_INDEX="${3:-1}"

if [ -z "$CONTACT" ] || [ -z "$FILEPATH" ]; then
  echo "Usage: line_file.sh <contact_name> <file_path> [result_index]"
  exit 1
fi
if [ ! -f "$FILEPATH" ]; then
  echo "ERROR: File not found: $FILEPATH"
  exit 1
fi
ABSPATH=$(cd "$(dirname "$FILEPATH")" && pwd)/$(basename "$FILEPATH")

# 1. Activate + pin
line_activate

# 2. Search
line_search "$CONTACT"

# 3. Pre-verify screenshot
BEFORE=$(line_shot before)
echo "MEDIA:$BEFORE"
line_log "before-screenshot: $BEFORE (confirm row $RESULT_INDEX title == \"$CONTACT\")"

# 4. Open chat
line_click_result "$RESULT_INDEX"

# 5. Attach + send file via AX file picker (wrong-file-proof)
# Propagate picker failure to the exit status — if panel_select aborts (e.g. the
# file isn't found), do NOT print a success message or exit 0.
if ! line_attach_file "$ABSPATH"; then
  line_close_chat
  line_hide
  echo "❌ LINE file NOT sent to $CONTACT (file picker aborted — name not found)."
  exit 1
fi

# 6. Post-verify
AFTER=$(line_shot after)
echo "MEDIA:$AFTER"
line_log "after-screenshot: $AFTER — verify the file bubble actually appeared"

# 7. Close the chat room (Esc) so LINE isn't left marking 已讀, then hide
line_close_chat
line_hide
echo "✅ Attempted LINE file send to $CONTACT: $(basename "$ABSPATH") — verify via $AFTER (never trust exit 0)."
