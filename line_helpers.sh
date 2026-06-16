#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# line_helpers.sh — shared functions for LINE automation scripts
# Source at the top of any line_*.sh script:
#   source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"

# ── Per-machine coordinate overrides ────────────────────────────────────────
# Every coordinate below is ${VAR:-default}, overridable WITHOUT editing this
# file: export the var, or (preferred) drop a git-ignored
# messaging_coords.local.sh next to this file. Run ./calibrate.sh to generate it
# for YOUR screen. With nothing overridden, every value falls back to the
# original 2026/06 calibration — behaviour is identical to before.
_LINE_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
[ -f "$_LINE_HELPER_DIR/messaging_coords.local.sh" ] && . "$_LINE_HELPER_DIR/messaging_coords.local.sh"

# ── LINE window geometry (pinned) — 1440×794 @ (0,30) ──
LINE_WIN_X=${LINE_WIN_X:-0} ; LINE_WIN_Y=${LINE_WIN_Y:-30} ; LINE_WIN_W=${LINE_WIN_W:-1440} ; LINE_WIN_H=${LINE_WIN_H:-794}

# ── Calibrated coords (2026/06, live-verified) ──
# Search results
LINE_RESULT_X=${LINE_RESULT_X:-150} ; LINE_RESULT_ROW1_Y=${LINE_RESULT_ROW1_Y:-198} ; LINE_ROW_H=${LINE_ROW_H:-70}
# Call dropdown
LINE_PHONE_ICON_X=${LINE_PHONE_ICON_X:-1370} ; LINE_PHONE_ICON_Y=${LINE_PHONE_ICON_Y:-112}
LINE_VOICE_X=${LINE_VOICE_X:-1375} ; LINE_VOICE_Y=${LINE_VOICE_Y:-157}
LINE_VIDEO_X=${LINE_VIDEO_X:-1375} ; LINE_VIDEO_Y=${LINE_VIDEO_Y:-185}
# Attach (paperclip) button
LINE_ATTACH_X=${LINE_ATTACH_X:-402} ; LINE_ATTACH_Y=${LINE_ATTACH_Y:-802}
# Input field center (from AX: text area 1 of splitter group 1 of splitter group 1)
LINE_INPUT_X=${LINE_INPUT_X:-908} ; LINE_INPUT_Y=${LINE_INPUT_Y:-748}

# ── Logging ──
line_log() { echo "[line] $*"; }

# ── Screenshot ──
line_shot() {
  local label="${1:-snap}"
  local p="/tmp/line_${label}_$(date +%s).png"
  screencapture -x "$p"
  echo "$p"
}

# ── Activate LINE, pin window to known geometry ──
line_activate() {
  open -a Line
  sleep 1.5
  osascript << 'ASEOF' >/dev/null 2>&1
tell application "LINE" to activate
delay 0.6
tell application "System Events"
  tell process "LINE"
    set frontmost to true
    try
      tell window "LINE"
        set position to {0, 30}
        set size to {1440, 794}
      end tell
    end try
  end tell
end tell
ASEOF
  sleep 0.6
}

# ── Search for a contact via AX set value (CJK-safe) ──
line_search() {
  local contact="$1"
  osascript << ASEOF >/dev/null 2>&1
tell application "System Events"
  tell process "LINE"
    tell window "LINE"
      tell splitter group 1
        set value of text field 1 to "$contact"
      end tell
    end tell
  end tell
end tell
ASEOF
  sleep 1.5
}

# ── Click search result row N (1-indexed) ──
line_click_result() {
  local idx="${1:-1}"
  local click_y=$((LINE_RESULT_ROW1_Y + (idx - 1) * LINE_ROW_H))
  cliclick c:${LINE_RESULT_X},${click_y}
  sleep 1
}

# ── Click input field via AX position, then set value from clipboard ──
# Usage: printf 'text' | pbcopy; line_send_text
line_send_text() {
  # Click the input area using AX-derived center
  osascript << 'ASEOF' >/dev/null 2>&1
tell application "System Events"
  tell process "LINE"
    try
      set ta to text area 1 of splitter group 1 of splitter group 1 of window "LINE"
      set p to position of ta
      set s to size of ta
      set cx to (item 1 of p) + ((item 1 of s) / 2)
      set cy to (item 2 of p) + ((item 2 of s) / 2)
      do shell script "cliclick c:" & (cx as integer) & "," & (cy as integer)
    end try
  end tell
end tell
ASEOF
  sleep 0.4
  # Set value from clipboard via AXFocusedUIElement
  local result
  result=$(osascript << 'ASEOF' 2>&1
tell application "System Events"
  set f to value of attribute "AXFocusedUIElement" of process "LINE"
  if class of f is text area then
    set value of f to (the clipboard as text)
    return "ok"
  else
    return "error: focus is " & (class of f as string) & ", not text area"
  end if
end tell
ASEOF
  )
  if [[ "$result" == error* ]]; then
    line_log "⚠️ $result"
    return 1
  fi
  sleep 0.3
  # Press Enter to send
  osascript -e 'tell application "System Events" to tell process "LINE" to key code 36'
  sleep 0.8
}

# ── Start a voice/video call (from inside an open chat) ──
line_start_call() {
  local call_type="${1:-voice}"
  cliclick c:${LINE_PHONE_ICON_X},${LINE_PHONE_ICON_Y}
  sleep 1
  if [ "$call_type" = "video" ]; then
    cliclick c:${LINE_VIDEO_X},${LINE_VIDEO_Y}
  else
    cliclick c:${LINE_VOICE_X},${LINE_VOICE_Y}
  fi
  sleep 1.5
  # Confirm the "確定要與X進行通話?" dialog (Enter = 開始)
  osascript -e 'tell application "System Events" to tell process "LINE" to key code 36'
  sleep 0.8
}

# ── Hang up (Escape → "您要結束通話嗎?" → Enter = 結束通話) ──
line_hangup() {
  osascript -e 'tell application "System Events" to tell process "LINE" to key code 53'
  sleep 0.6
  osascript -e 'tell application "System Events" to tell process "LINE" to key code 36'
  sleep 0.5
}

# ── Attach + send a file via the paperclip → AX file picker ──
# Wrong-file-proof, like wa_send_file: stage the file in ~/Downloads (a reliable
# sidebar location), then drive the open panel ENTIRELY via Accessibility — click
# the "下載項目" sidebar entry, then select the row whose name matches EXACTLY
# (panel_select.scpt). If the name isn't found it ABORTS without sending.
# This replaces the old Cmd+Shift+G + cliclick-type + Down + Enter flow, which
# could land on a stale folder and silently send the wrong file.
# Pass the FILE PATH (not a staging dir).
line_attach_file() {
  local filepath="$1"
  local base sendname dl rc
  base=$(basename "$filepath")

  # Stage in ~/Downloads under a name that does NOT already exist, so our later
  # `rm` can only ever delete the file we created (never a user file). Use the
  # original name if free; otherwise loop to a unique one.
  sendname="$base"
  dl="$HOME/Downloads/$sendname"
  while [[ -e "$dl" ]]; do
    sendname="hermes_$$_${RANDOM}_$base"
    dl="$HOME/Downloads/$sendname"
  done
  cp "$filepath" "$dl" || { line_log "stage copy failed"; return 1; }

  # Click paperclip → open panel
  cliclick c:${LINE_ATTACH_X},${LINE_ATTACH_Y}
  sleep 2.2

  # AX-select the file by exact name; abort (no send) if not found.
  rc=$(osascript "$_LINE_HELPER_DIR/panel_select.scpt" "LINE" "下載項目" "$sendname" 2>&1)
  if [[ "$rc" != "OK" ]]; then
    line_log "⚠️  file picker aborted ($rc) — cancelling, NOT sending"
    osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1
    rm -f "$dl"
    return 1
  fi

  # Open the selected file → LINE sends it
  osascript -e 'tell application "System Events" to key code 36'
  sleep 2
  rm -f "$dl"
}

# ── Close the open chat room (Esc) ──
# In LINE, Esc backs out one level: 1st press closes the search overlay, a
# further press closes the CHAT ROOM (back to the "開始聊天吧!" splash, nothing
# selected). Closing the chat means LINE isn't left sitting in a conversation
# marking later incoming messages 已讀. Two presses cover both states (an extra
# Esc on the splash is harmless).
line_close_chat() {
  osascript -e 'tell application "System Events" to tell process "LINE" to set frontmost to true' >/dev/null 2>&1
  osascript -e 'tell application "System Events" to tell process "LINE" to key code 53' >/dev/null 2>&1
  sleep 0.3
  osascript -e 'tell application "System Events" to tell process "LINE" to key code 53' >/dev/null 2>&1
  sleep 0.3
}

# ── Hide LINE ──
line_hide() {
  osascript -e 'tell application "System Events" to tell process "LINE" to keystroke "h" using command down' >/dev/null 2>&1
}
