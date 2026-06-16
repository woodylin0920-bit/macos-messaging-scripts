#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# wa_reply.sh <contact_name> <target_text_substring> <reply_message>
# Reply to a SPECIFIC WhatsApp message (quoted reply).
#   - Locate the target bubble by TEXT via Accessibility (wa_reply.scpt).
#   - Right-click it, then select 回覆 by KEYBOARD (Down → Enter) — the Electron
#     context menu is not AX-readable, but it IS keyboard-navigable, so we avoid
#     fragile pixel menu clicks and screenshots.
#   - Type the reply (AX set value) and send.
# Aborts (no send) if the target message isn't visible in the open chat.
#
#   wa_reply.sh "Alice" "下午要開會" "好的，我會準時到"

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wa_helpers.sh"

CONTACT="${1:?Usage: wa_reply.sh <name> <target_text> <reply>}"
TARGET="${2:?Usage: wa_reply.sh <name> <target_text> <reply>}"
REPLY="${3:?Usage: wa_reply.sh <name> <target_text> <reply>}"

# Open the chat (URL scheme if phone known, else search + AX pick)
PHONE=$(wa_get_phone "$CONTACT" 2>/dev/null || true)
if [[ -n "$PHONE" ]]; then
  open "whatsapp://send?phone=$PHONE"; sleep 3
  osascript -e 'tell application "WhatsApp" to activate' >/dev/null 2>&1
  sleep 0.3
  wa_pin_window
  sleep 0.6
else
  wa_activate
  wa_search "$CONTACT"
  # FAIL CLOSED: a reply SENDS — never guess. If the name isn't a unique match
  # (ambiguous / not found), abort instead of clicking row 1 and replying to the
  # wrong chat. (URL-scheme path above has no such ambiguity.)
  if ! wa_pick_chat_by_name "$CONTACT"; then
    wa_log "⚠️  '$CONTACT' 不是唯一相符(撞名/找不到)。為避免回覆到錯的人,中止不送。請用更精確的名字或已知號碼。"
    exit 1
  fi
fi
sleep 0.5

# Locate the target bubble by text → right-click point
POS=$(osascript "$SCRIPT_DIR/wa_reply.scpt" "$TARGET")
# Accept ONLY a strict numeric "x,y" — an ERR string (which may itself contain a
# comma from the target text) must NOT be mistaken for coordinates.
if [[ ! "$POS" =~ ^[0-9]+,[0-9]+$ ]]; then
  wa_log "⚠️  $POS — not replying (target not uniquely found)."
  wa_escape   # close the chat so it isn't left open marking incoming messages 已讀
  exit 1
fi
wa_log "Replying to message at $POS"

# Right-click → menu → Down → Enter (selects 回覆, the top item)
cliclick rc:"$POS"; sleep 0.9
osascript -e 'tell application "System Events" to key code 125'; sleep 0.4
osascript -e 'tell application "System Events" to key code 36'; sleep 0.8

# Type the reply into the (now focused) input and send
printf '%s' "$REPLY" | pbcopy
osascript << 'EOF'
tell application "System Events"
  tell process "WhatsApp" to set frontmost to true
  set f to value of attribute "AXFocusedUIElement" of process "WhatsApp"
  if class of f is text area then
    set value of f to (the clipboard as text)
  else
    error "WhatsApp focus is " & (class of f as string) & ", not text area — reply box not focused"
  end if
end tell
EOF
sleep 0.3
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
sleep 0.8
wa_escape
echo "✅ Replied to \"$TARGET\" in $CONTACT's chat."
