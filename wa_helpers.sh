#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# wa_helpers.sh — shared functions for WhatsApp automation scripts

# ── Per-machine coordinate overrides ────────────────────────────────────────
# Every coordinate below is written as ${VAR:-default}, so it can be overridden
# WITHOUT editing this file: either export the var, or (preferred) drop a
# git-ignored messaging_coords.local.sh next to this file. Run ./calibrate.sh to
# generate that file for YOUR screen. With nothing overridden, every value falls
# back to the original 2026/06 calibration — behaviour is identical to before.
_WA_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
[ -f "$_WA_HELPER_DIR/messaging_coords.local.sh" ] && . "$_WA_HELPER_DIR/messaging_coords.local.sh"

# Fixed window frame (screen points)
WA_WIN_X=${WA_WIN_X:-0}
WA_WIN_Y=${WA_WIN_Y:-25}
WA_WIN_W=${WA_WIN_W:-1440}
WA_WIN_H=${WA_WIN_H:-875}

# Search result coordinates (2026/06 calibrated)
WA_SEARCH_ROW1_Y=${WA_SEARCH_ROW1_Y:-197}
WA_SEARCH_ROW_HEIGHT=${WA_SEARCH_ROW_HEIGHT:-68}

# Chat header icons (live-calibrated 2026/06 against actual window {0,30}/1440×796).
# The call icon opens a DROPDOWN; the menu opens slightly DOWN-RIGHT of the icon
# (items at x≈1390, NOT 1350 — old value missed). Click icon → then menu item.
WA_CALL_DROPDOWN_X=${WA_CALL_DROPDOWN_X:-1365}
WA_CALL_DROPDOWN_Y=${WA_CALL_DROPDOWN_Y:-58}
WA_VOICE_CALL_X=${WA_VOICE_CALL_X:-1390}
WA_VOICE_CALL_Y=${WA_VOICE_CALL_Y:-88}
WA_VIDEO_CALL_X=${WA_VIDEO_CALL_X:-1390}
WA_VIDEO_CALL_Y=${WA_VIDEO_CALL_Y:-110}

# Input field
WA_INPUT_X=${WA_INPUT_X:-850}
WA_INPUT_Y=${WA_INPUT_Y:-795}

# Attachment "+" button — bottom-left of the input bar (live-calibrated 2026/06).
# Clicking it opens a popup MENU (檔案 / 照片和影片 / 投票 / 活動 / 聯絡人); to
# send an arbitrary file click "檔案" (top item) → Finder opens.
WA_ATTACH_X=${WA_ATTACH_X:-363}
WA_ATTACH_Y=${WA_ATTACH_Y:-802}
WA_ATTACH_FILE_X=${WA_ATTACH_FILE_X:-415}   # "檔案" menu item (top of the + popup)
WA_ATTACH_FILE_Y=${WA_ATTACH_FILE_Y:-603}
# Open-panel first file row. LEGACY: the file send now picks files via AX
# (panel_select.scpt), so these coords are no longer used by wa_send_file. Kept
# only as a fallback reference; safe to ignore.
WA_PANEL_ROW1_X=${WA_PANEL_ROW1_X:-490}
WA_PANEL_ROW1_Y=${WA_PANEL_ROW1_Y:-310}

# Privacy-popup close X ("你的對話和通話均受隱私保護" modal)
WA_PRIVACY_X=${WA_PRIVACY_X:-590}
WA_PRIVACY_Y=${WA_PRIVACY_Y:-140}

wa_log() { echo "[wa] $*" >&2; }

# ── Curated WhatsApp numbers (source of truth = WhatsApp, NOT Contacts) ──
# Contacts.app can be stale vs WhatsApp (e.g. Alice's Contacts entry was an
# old US number; his real WhatsApp number is the Canada one below). Put anyone
# you actually message on WhatsApp here, with their CURRENT WhatsApp number.
# Format: international digits only, no '+' or spaces.
#
# NOTE: a `case` statement (NOT an associative array) — macOS /bin/bash is 3.2
# and does not support `declare -A`. Add a contact by adding a case branch.
# The name arg is already lowercased by wa_get_phone, so match in lowercase.
# Replace these example branches with YOUR OWN contacts. Format: international
# digits only, no '+' or spaces (e.g. Taiwan 0912-345-678 -> 886912345678).
wa_curated_phone() {
  case "$1" in
    alice)       echo "886912345678" ;;   # <- example, replace with a real contact
    "bob smith") echo "14155550123" ;;     # <- example, replace with a real contact
    *)           echo "" ;;
  esac
}

# wa_get_phone <name> — resolve a WhatsApp-ready number (digits only, no '+').
# Lookup order: (1) curated WA_PHONES table, (2) macOS Contacts as fallback.
# On no-match / ambiguous-match prints "" + nonzero exit (candidates -> stderr).
# It does NOT guess between multiple Contacts matches — that's the
# anti-wrong-person rule; caller should fall back to the vision-verified search.
#
# Contacts normalization handles Taiwan local format:
#   "0912-345-678" -> "886912345678"  |  "+886 912 345 678" -> "886912345678"
wa_get_phone() {
  local name="$1"
  local key curated
  key=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
  curated=$(wa_curated_phone "$key")
  if [[ -n "$curated" ]]; then
    echo "$curated"
    return 0
  fi

  # NOTE: write the AppleScript to a temp file then run it — macOS /bin/bash is
  # 3.2 and CANNOT parse a heredoc inside $() command substitution. Don't inline.
  local scpt raw
  scpt=$(mktemp /tmp/wa_getphone.XXXXXX) || { echo ""; return 1; }
  cat > "$scpt" <<EOF
on findMatches(q, mode)
  tell application "Contacts"
    if mode is "exact" then
      set matches to (every person whose name is q)
    else
      set matches to (every person whose name contains q)
    end if
    set valid to {}
    repeat with p in matches
      if (count of phones of p) > 0 then set end of valid to p
    end repeat
    return valid
  end tell
end findMatches

tell application "Contacts"
  set valid to my findMatches("$name", "exact")
  if (count of valid) is 0 then set valid to my findMatches("$name", "contains")
  if (count of valid) is 1 then
    return value of phone 1 of (item 1 of valid)
  else if (count of valid) > 1 then
    set nms to {}
    repeat with p in valid
      set end of nms to name of p
    end repeat
    set AppleScript's text item delimiters to ", "
    return "AMBIGUOUS:" & (nms as text)
  else
    return ""
  end if
end tell
EOF
  raw=$(osascript "$scpt" 2>/dev/null || true)
  rm -f "$scpt"
  if [[ "$raw" == AMBIGUOUS:* ]]; then
    wa_log "⚠️  '$name' 對到多筆通訊錄，不亂猜：${raw#AMBIGUOUS:} — 請用更精確的名字或 vision 確認"
    echo ""; return 1
  fi
  if [[ -z "$raw" ]]; then
    wa_log "找不到 '$name'（不在 WA_PHONES，通訊錄也沒有或沒存電話）"
    echo ""; return 1
  fi
  local d
  d=$(printf '%s' "$raw" | tr -cd '0-9+')
  if [[ "$d" == +* ]]; then
    echo "${d//+/}"
  elif [[ "$d" == 00* ]]; then
    echo "${d:2}"
  elif [[ "$d" == 0* ]]; then
    echo "886${d:1}"   # Taiwan local -> international
  else
    echo "$d"
  fi
}

# wa_list_contacts [filter] — browse YOUR contacts ("Name | phone"), optionally
# filtered by substring:  wa_list_contacts            (everyone with a number)
#                         wa_list_contacts Alice    (just "Alice" matches)
wa_list_contacts() {
  local filter="${1:-}"
  osascript <<EOF 2>/dev/null
tell application "Contacts"
  set out to {}
  repeat with p in people
    if (count of phones of p) > 0 then
      set nm to name of p
      if "$filter" is "" or (nm contains "$filter") then
        set end of out to nm & " | " & (value of phone 1 of p)
      end if
    end if
  end repeat
  set AppleScript's text item delimiters to linefeed
  return out as text
end tell
EOF
}

# Pin the WhatsApp window to the (overridable) WA_WIN_* frame. Every click coord
# is calibrated relative to this frame, so ALL activation routes through here —
# that makes the WA_WIN_* overrides actually take effect.
wa_pin_window() {
  osascript >/dev/null 2>&1 <<EOF
tell application "System Events" to tell process "WhatsApp"
  set frontmost to true
  try
    tell window 1 to set {position, size} to {{$WA_WIN_X, $WA_WIN_Y}, {$WA_WIN_W, $WA_WIN_H}}
  end try
end tell
EOF
}

# Clear macOS notification banners (iPhone-mirror / reminders) from the top-right.
# They overlap the call icon and chat area, so cliclick can land on the banner
# instead of the target. killall is instant, needs no Accessibility permission, and
# NotificationCenter auto-relaunches. The `|| true` keeps it from aborting callers
# that run under `set -euo pipefail` when no banner process is present.
nc_clear() { killall NotificationCenter >/dev/null 2>&1 || true; }

wa_activate() {
  nc_clear
  open -a WhatsApp
  sleep 1
  osascript -e 'tell application "WhatsApp" to activate' >/dev/null 2>&1
  sleep 0.3
  wa_pin_window
  osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 53' >/dev/null 2>&1
  sleep 0.2
  osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 53' >/dev/null 2>&1
  sleep 0.2
}

wa_screenshot() {
  local out="${1:-/tmp/wa_screenshot_$(date +%s).png}"
  screencapture -x /tmp/_wa_raw.png
  sips -Z 1400 /tmp/_wa_raw.png -o "$out" >/dev/null 2>&1
  rm -f /tmp/_wa_raw.png
  echo "$out"
}

wa_escape() {
  osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 53'
  sleep 0.2
}

wa_search_row_y() {
  local index="${1:-1}"
  echo $(( WA_SEARCH_ROW1_Y + (index - 1) * WA_SEARCH_ROW_HEIGHT ))
}

wa_search() {
  local name="$1"
  printf '%s' "$name" | pbcopy
  osascript << 'SRCHEOF'
tell application "System Events"
  tell process "WhatsApp"
    keystroke "f" using command down
    delay 0.5
    keystroke "a" using command down
    delay 0.1
    key code 51
    delay 0.2
    keystroke "v" using command down
  end tell
end tell
SRCHEOF
  sleep 1.2
}

wa_click_result() {
  local index="${1:-1}"
  local y
  y=$(wa_search_row_y "$index")
  cliclick c:197,"$y"
  sleep 0.8
}

# ── AX-pick a chat by EXACT name (preferred over wa_click_result) ──
# Rows are AXButtons whose description is the contact name, so we click the
# matching one directly — no pixel row coords, no unstable-order wrong-person
# risk. Returns 0 only when EXACTLY ONE row matched (clicked it); nonzero when
# none or several matched (e.g. a name colliding with the self-chat). On nonzero
# the caller falls back to the vision-gated wa_click_result — never a blind guess.
wa_pick_chat_by_name() {
  local name="$1" rc
  rc=$(osascript "$_WA_HELPER_DIR/wa_pick.scpt" "$name" 2>&1)
  if [[ "$rc" == "OK" ]]; then
    sleep 0.8
    return 0
  fi
  wa_log "AX pick: $rc"
  return 1
}

wa_start_call() {
  local type="${1:-voice}"
  nc_clear; sleep 0.2   # wipe any banner that popped over the call icon
  cliclick c:${WA_CALL_DROPDOWN_X},${WA_CALL_DROPDOWN_Y}
  sleep 0.5
  if [[ "$type" == "video" ]]; then
    cliclick c:${WA_VIDEO_CALL_X},${WA_VIDEO_CALL_Y}
  else
    cliclick c:${WA_VOICE_CALL_X},${WA_VOICE_CALL_Y}
  fi
  sleep 1.5
}

wa_hangup() {
  local close_pos
  close_pos=$(osascript -e '
tell application "System Events"
  tell process "WhatsApp"
    set frontmost to true
    repeat with w in (every window)
      set sz to size of w
      if (item 1 of sz) is not '"$WA_WIN_W"' then
        perform action "AXRaise" of w
        set p to position of w
        set cx to ((item 1 of p) + 8)
        set cy to ((item 2 of p) + 7)
        return (cx as string) & "," & (cy as string)
      end if
    end repeat
    return ""
  end tell
end tell
')
  if [[ -n "$close_pos" ]]; then
    cliclick c:"$close_pos"
    wa_log "Hung up ($close_pos)"
    return 0
  else
    wa_log "No call window found"
    return 1
  fi
}

wa_send_message() {
  local msg="$1"
  printf '%s' "$msg" | pbcopy
  cliclick c:${WA_INPUT_X},${WA_INPUT_Y}
  sleep 0.3
  # Use AXFocusedUIElement `set value` — NOT Cmd+V. Empirically (2026/06) the
  # Cmd+V keystroke silently fails to land in WhatsApp's WebView input under
  # automation (focus/frontmost timing), leaving the box empty. `set value`
  # directly writes the text area and is reliable — this is what send_msg.sh
  # has always used. It also REPLACES any leftover draft (no Cmd+A needed).
  osascript << 'EOF'
tell application "System Events"
  tell process "WhatsApp" to set frontmost to true
  set f to value of attribute "AXFocusedUIElement" of process "WhatsApp"
  if class of f is text area then
    set value of f to (the clipboard as text)
  else
    error "WhatsApp focus is " & (class of f as string) & ", not text area — input click missed or a modal is blocking"
  end if
end tell
EOF
  sleep 0.3
  osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
  sleep 0.5
}

# ── Pre-check: dismiss the privacy modal that silently blocks the input ──
# The "你的對話和通話均受隱私保護" full-screen modal covers the chat/input area.
# Clicking the X at WA_PRIVACY_X,Y is harmless if no popup is present (empty
# space). Returns 0 always; this is a best-effort safety click.
wa_dismiss_privacy_popup() {
  cliclick c:${WA_PRIVACY_X},${WA_PRIVACY_Y}
  sleep 0.2
  wa_escape   # Escape as a second dismiss path (also harmless)
  sleep 0.2
}

# ── Focus check: is the AX focus actually a text area? (0 = yes, 1 = no) ──
wa_focus_is_textarea() {
  local cls
  cls=$(osascript -e 'tell application "System Events" to return (class of (value of attribute "AXFocusedUIElement" of process "WhatsApp")) as string' 2>/dev/null)
  [[ "$cls" == "text area" ]]
}

# ── Pre-check before any send/call: pin window, dismiss popup, screenshot ──
# Echoes the BEFORE screenshot path. Caller passes it to vision to confirm the
# right chat / no blocking modal BEFORE acting.
wa_precheck() {
  local tag="${1:-action}"
  wa_dismiss_privacy_popup
  local shot="/tmp/wa_before_${tag}_$(date +%s).png"
  wa_screenshot "$shot" >/dev/null
  echo "$shot"
}

# ── Post-verify after any send/call: screenshot the result ──
# Echoes the AFTER screenshot path. Caller (or Hermes vision) confirms the
# green bubble / call record actually appeared. NEVER trust a bare exit 0.
wa_postverify() {
  local tag="${1:-action}"
  sleep 0.6
  local shot="/tmp/wa_after_${tag}_$(date +%s).png"
  wa_screenshot "$shot" >/dev/null
  echo "$shot"
}

# ── Send a file via the attachment "+" → 檔案 → AX file picker ──
# Robust, wrong-file-proof selection: stage the file in ~/Downloads (a reliable
# sidebar location), then drive the macOS open panel ENTIRELY via Accessibility —
# click the "下載項目" sidebar entry, then select the row whose name matches the
# file EXACTLY (panel_select.scpt). If the name isn't found it ABORTS without
# sending. This replaces the old Cmd+Shift+G + Down + Enter flow, which on some
# machines silently selected whatever file the panel was sitting on and sent it.
# Optional $2 = caption text (shown under the file in the send preview).
# Chat must already be open.
wa_send_file() {
  local filepath="$1"
  local caption="${2:-}"
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
  cp "$filepath" "$dl" || { wa_log "stage copy failed"; return 1; }

  # 1. + popup → 檔案 → open panel
  cliclick c:${WA_ATTACH_X},${WA_ATTACH_Y}
  sleep 0.9
  cliclick c:${WA_ATTACH_FILE_X},${WA_ATTACH_FILE_Y}
  sleep 2.2

  # 2. AX-select the file by exact name (sidebar Downloads → match name). This
  #    cannot pick the wrong file: a miss returns "ERR:" and we cancel + bail.
  rc=$(osascript "$_WA_HELPER_DIR/panel_select.scpt" "WhatsApp" "下載項目" "$sendname" 2>&1)
  if [[ "$rc" != "OK" ]]; then
    wa_log "⚠️  file picker aborted ($rc) — cancelling, NOT sending"
    osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1
    rm -f "$dl"
    return 1
  fi

  # 3. Open the selected file (default button) → WhatsApp shows the send preview
  osascript -e 'tell application "System Events" to key code 36'
  sleep 2

  # 4. Optional caption
  if [[ -n "$caption" ]]; then
    printf '%s' "$caption" | pbcopy
    osascript << 'EOF'
tell application "System Events"
  set f to value of attribute "AXFocusedUIElement" of process "WhatsApp"
  try
    if class of f is text area then set value of f to (the clipboard as text)
  end try
end tell
EOF
    sleep 0.3
  fi

  # 5. Send (Enter in the preview)
  osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
  sleep 1.5

  rm -f "$dl"
  wa_postverify file
}
