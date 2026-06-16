#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# wa_file.sh <contact_name> <file_path> [result_index] [caption]
# URL scheme preferred (if phone known), search fallback.
# Attach via + → 檔案 → panel_select.scpt (AX picks the file by exact name).
#
# ⚠️ Search fallback: result order is UNSTABLE — use vision to confirm!

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wa_helpers.sh"

CONTACT="${1:-}"
FILEPATH="${2:-}"
RESULT_INDEX="${3:-1}"
CAPTION="${4:-}"

if [[ -z "$CONTACT" || -z "$FILEPATH" ]]; then
  echo "Usage: wa_file.sh <contact_name> <file_path> [result_index] [caption]"
  exit 1
fi

if [[ ! -f "$FILEPATH" ]]; then
  echo "ERROR: File not found: $FILEPATH"
  exit 1
fi

ABSPATH=$(cd "$(dirname "$FILEPATH")" && pwd)/$(basename "$FILEPATH")
PHONE=$(wa_get_phone "$CONTACT" 2>/dev/null || true)

if [[ -n "$PHONE" ]]; then
  wa_log "Opening $CONTACT via URL scheme ($PHONE)"
  open "whatsapp://send?phone=$PHONE"
  sleep 3
  osascript -e 'tell application "WhatsApp" to activate' >/dev/null 2>&1
  sleep 0.3
  wa_pin_window
  sleep 0.6
else
  wa_log "No phone for $CONTACT, using search (result #$RESULT_INDEX)"
  wa_activate
  wa_search "$CONTACT"
  if ! wa_pick_chat_by_name "$CONTACT"; then
    wa_log "AX pick failed — falling back to result #$RESULT_INDEX (VISION-CONFIRM the row!)"
    wa_click_result "$RESULT_INDEX"
  fi
fi

wa_log "Sending file to $CONTACT: $ABSPATH"
AFTER=$(wa_send_file "$ABSPATH" "$CAPTION")
wa_log "after-screenshot: $AFTER"

wa_escape
echo "MEDIA:$AFTER"
wa_log "✅ File sent to $CONTACT: $(basename "$ABSPATH")"
