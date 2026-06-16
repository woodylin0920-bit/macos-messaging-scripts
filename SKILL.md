---
name: macos-messaging
description: |
  Automate LINE and WhatsApp on macOS: open chats, read chat list, send
  messages, and make voice/video calls via AppleScript + System Events +
  cliclick. Covers popup vs full-window mode, AX tree quirks, WebView
  apps, and the universal AXFocusedUIElement trick for reliable text input.
version: 6.3.0
platforms: [macos]
metadata:
  hermes:
    tags: [line, whatsapp, macos, applescript, automation, messaging]
    category: apple
    related_skills: [macos-computer-use, imessage]
---

# macOS Messaging Automation (LINE + WhatsApp)

Automate LINE and WhatsApp desktop apps on macOS using AppleScript +
System Events + `cliclick`. Covers chat navigation, AX tree quirks, and
the **universal input trick** that works across both apps.

## Prerequisites

1. **Accessibility permission** — System Settings → Privacy & Security →
   Accessibility → add Terminal (or the shell running Hermes).
   Without this: `osascript不允許輔助取用 (-25211)`

2. **cliclick** — for reliable coordinate clicks and double-clicks:
   ```bash
   brew install cliclick
   ```

---

## Environment constraints & contact resolution (2026/06)

### macOS `/bin/bash` is **3.2** — two hard limits
The scripts run under the system bash 3.2 (not Homebrew bash). Two things will
silently break a script if you forget:
1. **No `declare -A` (associative arrays).** Use a `case` statement instead.
   `wa_curated_phone()` in `wa_helpers.sh` is a `case` table for this reason.
2. **No heredoc inside `$(...)` command substitution.** A `cat <<EOF` inside
   `$( )` fails to parse. Write the AppleScript to a temp file with `cat > "$f"
   <<EOF`, then `osascript "$f"` and `rm` it. See `wa_get_phone`.

### Contact → WhatsApp number resolution (`wa_get_phone`)
Lookup order: **(1) curated `wa_curated_phone` case table → (2) macOS Contacts**.
- **Curated table is the source of truth**, NOT Contacts. Contacts can be stale
  or hold non-WhatsApp numbers. Add people you actually WhatsApp here.
- **Taiwan number normalization:** `0xxxxxxxxx` → strip `0`, prepend `886`;
  `+xxx` → strip `+`; `00xxx` → strip `00`.
- **Ambiguous (Contacts `name contains` returns >1) → return empty + log
  candidates, never guess.** This is the anti-wrong-person rule.

⚠️ **Duplicate-contact gotcha:** a person can have several entries in Contacts
(an old number, a work number, even your OWN number saved under their name), and
none of them may be the WhatsApp number. Opening your own number via the URL
scheme silently lands on the self-chat. Always resolve through the curated table
above; never trust Contacts to pick the right one when a name is ambiguous.

### Window geometry actually in use (re-pin before any coordinate op)
| App | Pinned frame (position / size) |
|-----|--------------------------------|
| WhatsApp | {0, 25} / {1440, 875} (height may cap to ~796 — X/top coords stay valid) |
| LINE | {0, 30} / {1440, 794} (NOT 1440×900 — old assumption caused drift) |

### Scripts lose `+x` when rewritten
`skill_manage`/`write_file` overwrites drop the execute bit. **`chmod +x` after
every script write.**

---

## ★ Live-verified findings (2026/06) — read this first

A full end-to-end live test pass against the test targets confirmed these. They
override older guesses elsewhere in this doc.

**LINE voice/video call — driven by KEYBOARD, no fragile button coords:**
- phone icon `(1370,112)` → dropdown → 語音通話 `(1375,157)` / 視訊通話 `(1375,185)`
- the "確定要與X進行通話?" confirm dialog → **Enter (key code 36)** = 開始
- hang up: **Escape (key code 53)** opens "您要結束通話嗎?" → **Enter** = 結束通話.
  Escape ALONE does NOT hang up. `取消` in the log = you ended it; `無回應` = it
  rang out on its own. The dialog/call UI is an overlay (buttons not in AX tree).

**LINE text input:** click the input (AX gives center ≈ `(908,748)` for the
pinned frame — query `text area 1 of splitter group 1 of splitter group 1 of
window "LINE"`), then `set value` on AXFocusedUIElement (CJK-safe). `send_msg.sh`
RE-activates LINE and loses input focus — use `line_msg.sh` instead.

**LINE search results: ORDER IS UNSTABLE — vision-confirm the row, never trust a
fixed index.** Row1 center ≈ `(150,200)`, height ≈70. In testing, a blind row-1
click once opened "自用群組" (the user's OWN chat) instead of "Alice" — a
near wrong-person send. Hermes MUST screenshot → vision-confirm the row title ==
the intended contact BEFORE clicking. AX can't read LINE row titles, so this is
vision-only.

**File send — drive the open panel via Accessibility, NEVER Cmd+Shift+G.**
The old approach (Cmd+Shift+G → type/paste a path → Down → Enter) is **banned**:
it silently sends the WRONG file. Live-confirmed 2026/06 — WhatsApp's Electron
open panel just **ignores Cmd+Shift+G**, so the panel stays on whatever folder it
last remembered (e.g. `~/Downloads/bst_boost_interprocess`) and `Down → Enter`
selects+sends the first file there. Exit 0, no error, a stray file lands in the
chat. (It happened during testing; the file had to be recalled with
「為所有人刪除」.)

**The robust, wrong-file-proof method (`panel_select.scpt`) — used by both apps:**
1. Stage the file in **`~/Downloads`** (a reliable sidebar location). Keep the
   original name unless it would clobber an existing file → then a unique name,
   so cleanup never deletes the user's own file.
2. Open the panel (WhatsApp: + → 檔案; LINE: 📎 paperclip).
3. Run `panel_select.scpt <proc> 下載項目 <filename>` — it drives the NSOpenPanel
   **entirely via AX**: clicks the「下載項目」sidebar row to navigate, then selects
   the file ROW whose name matches **exactly**. Returns `OK`, or `ERR:` if the
   exact name isn't visible.
4. If `ERR:` → **Escape the panel and ABORT (do NOT send).** A wrong file can
   never go out, because send only happens after an exact-name match.
5. Press Return (the default Open button). WhatsApp shows a send preview (add
   caption, Enter to send); LINE sends immediately.
6. Remove the staged file from `~/Downloads`.

Both `wa_send_file` and `line_attach_file` implement this. The open panel is a
`sheet 1 of window 1` of each app process (LINE's is **not** a separate XPC
process here) and its sidebar labels + file rows are **fully AX-readable** — so
no pixel coordinates and no Cmd+Shift+G are involved in file selection at all.

**WhatsApp call icon = dropdown:** `(1365,58)` → 語音 `(1390,88)` / 視訊
`(1390,110)`. `wa_hangup` closes the call window (width≠1440) via its traffic-light.

---

## Text input — LINE vs WhatsApp (DIFFERENT methods!)

### LINE — AX `set value` (bypasses input method)
```bash
printf 'Your message here' | pbcopy
cliclick c:X,Y   # click input field
osascript -e '
tell application "System Events"
  set f to value of attribute "AXFocusedUIElement" of process "LINE"
  if class of f is text area then
    set value of f to (the clipboard as text)
  end if
end tell
'
osascript -e 'tell application "System Events" to tell process "LINE" to key code 36'
```
`keystroke` and `Cmd+V` are unreliable for LINE — focus jumps.
`AXFocusedUIElement` + `set value` is the only reliable method.

### WhatsApp — use `set value` (reliable); `Cmd+V` is FLAKY under automation
✅ **CORRECTED + live-verified 2026/06:** the old claim "`set value` is silently
ignored on WhatsApp's WebView, use Cmd+V" was **backwards**. Live testing shows:
- **`set value` on `AXFocusedUIElement` is the RELIABLE method** (what
  `send_msg.sh` and `wa_send_message` use). It directly writes the text area and
  also replaces any leftover draft.
- **`Cmd+V` keystroke FREQUENTLY FAILS** under automation — the paste silently
  doesn't land in the WebView input (focus/frontmost timing), leaving the box
  empty and nothing sent (exit 0 lie). Verified: clicking the input returned
  `text area`, yet Cmd+V left the box empty; `set value` filled it every time.

The real gate either way is **focus must be on a `text area`** (not a `group` —
that means the search panel still has focus; click the input again). Prefer
`set value`:

**Path A — `set value` (RECOMMENDED — same as LINE, what `send_msg.sh` uses):**
```bash
printf 'Your message here' | pbcopy
cliclick c:850,795   # click input field (pinned-frame coord, see WhatsApp SOP)
sleep 0.3
osascript << 'EOF'
tell application "System Events"
  set f to value of attribute "AXFocusedUIElement" of process "WhatsApp"
  if class of f is text area then
    set value of f to (the clipboard as text)
  else
    error "Focus 不在 text area（多半是搜尋面板還握著焦點）— 先 Escape 再點輸入框"
  end if
end tell
EOF
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
```

**Path B — `Cmd+V` paste (also fine for English + CJK):**
```bash
printf 'Your message here' | pbcopy
cliclick c:850,795
sleep 0.3
osascript -e 'tell application "System Events" to tell process "WhatsApp" to keystroke "v" using command down'
sleep 0.3
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
```
`keystroke "hello"` also works for ASCII but goes through the input method
(CJK gets eaten by 注音). For CJK use `set value` or `Cmd+V`, never `keystroke`.
**The real failure mode is focus, not the method** — always check `class of f`
is `text area` first; if it's `group`, send Escape and re-click the input.

---

## LINE SOP

### 1. Open and expand to full window
LINE launches as a mini popup — always expand first:
```bash
open -a Line && sleep 1
osascript -e '
tell application "LINE" to activate
delay 0.5
tell application "System Events"
  tell process "LINE"
    tell window "LINE"
      click button 3   -- expand button
    end tell
  end tell
end tell
'
```

### 2. Read chat list — screenshot + vision (most reliable)
AX `description` / `entire contents` on LINE rows returns empty — use vision:
```bash
screencapture -x /tmp/line_chatlist.png
# vision_analyze: "前五個聊天室名稱是什麼？"
```

### 3. Navigate to a chat
Get AX position of the row, then cliclick:
```applescript
tell application "System Events"
  tell process "LINE"
    tell window "LINE"
      tell splitter group 1
        tell list 1
          set el to UI element 1 of row N
          set pos to position of el
          set sz to size of el
          -- center = pos[0] + sz[0]/2, pos[1] + sz[1]/2
        end tell
      end tell
    end tell
  end tell
end tell
```
```bash
cliclick c:CX,CY    # single click to open
cliclick dc:CX,CY   # double click if single doesn't open
```

### 4. LINE input field — AX path
```
window "LINE" > splitter group 1 > splitter group 1 > text area 1
```
Get its position:
```applescript
tell application "System Events"
  tell process "LINE"
    tell window "LINE"
      tell splitter group 1
        tell splitter group 1
          set ta to text area 1
          set pos to position of ta
          set sz to size of ta
          -- click center: pos[0]+sz[0]/2, pos[1]+sz[1]/2
        end tell
      end tell
    end tell
  end tell
end tell
```
Then use the **universal input trick** above.

---

## WhatsApp SOP

### 1. Open and navigate to a chat
```bash
open -a WhatsApp && sleep 1
# Read chat list via screencapture + vision
# Click the target chat row by coordinate (vision gives you the y position)
```

### 2. WhatsApp input field
WhatsApp uses a WebView internally — AX tree is very deep and fragile.
**Do NOT try to traverse to the text area via AX path.** Instead:

```bash
# ⚠️ If arriving from a search flow, press Escape FIRST to drop search panel focus.
# Without this, clicking the input field lands on a `group` (not `text area`).
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 53'
sleep 0.3

# Click the input field by coordinate (from screencapture + vision)
cliclick c:555,740   # input bar is at bottom of chat area (use 555 not 540 — more reliable)

# Verify focus landed on a text area
osascript -e '
tell application "System Events"
  set f to value of attribute "AXFocusedUIElement" of process "WhatsApp"
  return class of f as string  -- should say "text area"
end tell
'
```

**Pitfall — search panel retains focus after clicking a result:** After searching
a contact and clicking the result row, the AX focus stays on the search panel
region. Clicking `c:540,740` then returns `group` instead of `text area`.
Fix: send `key code 53` (Escape) first to release search focus, THEN click the
input field. The slightly different X=555 is also more reliable than X=540.

If it says `text area`, use **Cmd+V paste** (see "Text input" section above).
⚠️ `AXFocusedUIElement set value` does NOT work for WhatsApp — the WebView ignores it silently.

### 3. Send
```bash
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
```

---

## Verification pattern

**Do NOT screenshot every step** — each `screencapture` + vision round-trip
causes a visible stutter/lag on screen that the user can see and feel.
Instead:

- **Batch actions with known coordinates** — chain cliclick calls with short
  sleeps, no screenshots in between.
- **Screenshot only at key decision points**: after search results appear
  (to find the right row), and once at the end to confirm final state.
- **Skip verification entirely** when using previously-validated coordinates
  (e.g. phone icon at 1370,110 — just click it, don't screenshot to confirm).

```bash
# Only when needed:
screencapture -x /tmp/verify.png
# vision_analyze to confirm expected state
```

---

## Checking for Replies
After sending, to check if someone replied:
```bash
osascript -e 'tell application "LINE" to activate' && sleep 0.8
screencapture -x /tmp/line_now.png
# vision_analyze: "有沒有任何聊天室顯示未讀訊息（紅色數字badge）？"
```
Check the target chat: open it, screenshot, vision_analyze for new messages after your last sent message.

**Note:** Opening a chat to check reads the messages — the unread badge clears. If the user asks "did they reply?", open LINE, screenshot the chat list FIRST to see badges before clicking in.

## LINE Chat List — row layout
The left panel lists recent chats top-to-bottom (contacts and groups). Row order
is UNSTABLE (changes with recent activity), so use screenshot+vision to read the
titles and get the Y coordinate each time — never hardcode a row index.

Click X is around 200 (left panel center). Y varies by window size — always screenshot+vision to confirm.

## Making a Voice Call — LINE

### ⚠️ MANDATORY: Human-in-the-loop confirmation before calling

**NEVER blindly call** based on search results. Search results include both
contacts AND groups, and their ordering is unstable (same query can return
different order each time). Blindly clicking the Nth result has caused
near-misses like initiating a group call to 35 people.

**The confirmed SOP (interactive, from chat):**

1. Search → screenshot → **send screenshot to user via `MEDIA:/path`**
2. User replies with which result number to call
3. THEN run `line_call.sh` with the correct `result_index`

**The confirmed SOP (cron / scheduled):**
Use `no_agent=true` + `line_call.sh` only for contacts where the search
term reliably returns the target as the 1st result (e.g. "mong7"). For
ambiguous names, use an LLM-based cron job with a vision checkpoint.

### Interactive call flow (from chat)

```bash
# 1. Open & activate LINE
open -a Line
sleep 1.5
osascript -e 'tell application "LINE" to activate'
sleep 0.8

# 2. Search using AX set value (NOT keystroke — input method issues)
osascript -e '
tell application "System Events"
  tell process "LINE"
    tell window "LINE"
      tell splitter group 1
        set value of text field 1 to "contact_name"
      end tell
    end tell
  end tell
end tell
'
sleep 1.5

# 3. Screenshot and SEND TO USER for confirmation
screencapture -x /tmp/line_search.png
# Hide LINE while waiting (don't leave search results on screen)
osascript -e 'tell application "System Events" to tell process "LINE" to keystroke "h" using command down'
# Reply to user with: MEDIA:/tmp/line_search.png
# WAIT for user to say which number (e.g. "4" or "第2個")

# 4. Once user confirms, run the script:
~/.hermes/scripts/line_call.sh "contact_name" <hang_up_seconds> <result_index>
```

### LINE coordinate reference (window PINNED to {0,30} size {1440,794}, 2026/06)
⚠️ **The window is NOT 1440×900.** LINE caps to **position (0,30), size 1440×794**
(≈106px shorter than the old assumption — that height delta was the #1 cause of
coordinate drift). `line_call.sh` now pins the window to this frame at the start;
all coords below are measured against it. Re-pin before any coordinate op.

⚠️ **LINE call icon is now a DROPDOWN (like WhatsApp), 2026/06.** Clicking the
phone icon opens a 語音/視訊 menu — you must click TWICE (icon → menu item).

| Element | Screen Point (x, y) | Status |
|---------|---------------------|--------|
| Search box (AX) | `set value of text field 1 of splitter group 1` — no coords | ✅ |
| Phone icon (opens dropdown) | **(1365, 114)** | ✅ calibrated |
| → 語音通話 (dropdown item) | **(1350, 152)** | ✅ calibrated (old 1310,143 was 40px off — the failure cause) |
| → 視訊通話 (dropdown item) | **(1350, 180)** | ✅ calibrated |
| 開始 (confirm dialog) | ~(725, 447) | ⚠️ PENDING live re-calibration |
| 取消 (confirm dialog) | ~(660, 447) | ⚠️ PENDING live re-calibration |
| 🔴 Hang-up button | ~(695, 645) | ⚠️ PENDING live re-calibration |
| Search result row1 click | ~(200, 190) — but **screenshot+vision confirm title first** | vision-gated |
| Input field (AX center) | **(908, 748)** | ✅ calibrated (AX: `text area 1 of splitter group 1 of splitter group 1`) |

The three ⚠️ rows need one live test call (voice → screenshot 開始 dialog → start →
short auto-hangup → screenshot hang-up button) to lock in. Until then `line_call.sh`
uses the ~approx values and post-verifies with a screenshot.

---

## Making a Voice Call — WhatsApp

### Same human-in-the-loop rule applies
Search → screenshot → send to user for confirmation → THEN call.

### ⚠️ CRITICAL: Do NOT hide WhatsApp between search and call

Unlike LINE, **WhatsApp clears search results when hidden (Cmd+H)**. If you
hide WhatsApp after searching, then reopen it, the search box is empty and
you're back to the main chat list. Clicking "result #1" then hits whatever
chat is at the top of the list — **not your search result**. This has caused
wrong-person calls.

**Correct flow:** Search → screenshot (keep WhatsApp open) → wait for user
confirmation → click result → call. Only hide AFTER the call ends.

### Interactive call flow

```bash
# 1. Hide any existing WhatsApp window first (clear previous chat — MANDATORY)
osascript -e 'tell application "System Events" to tell process "WhatsApp" to keystroke "h" using command down' 2>/dev/null
sleep 0.5

# 2. Open & activate WhatsApp
open -a WhatsApp
sleep 1.5
osascript -e 'tell application "WhatsApp" to activate'
sleep 0.8

# 3. Escape to close any open panel
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 53'
sleep 0.5

# 4. Search with Cmd+F (clicking search bar does NOT focus it!)
osascript -e '
tell application "System Events"
  tell process "WhatsApp"
    keystroke "f" using command down
  end tell
end tell
'
sleep 0.8
# Clear any previous search and type contact name
osascript -e '
tell application "System Events"
  tell process "WhatsApp"
    keystroke "a" using command down
    delay 0.2
    key code 51
  end tell
end tell
'
sleep 0.3
osascript -e "tell application \"System Events\" to keystroke \"$CONTACT\""
sleep 1.5

# 5. Screenshot — ⚠️ DO NOT HIDE WhatsApp! Search results disappear on hide.
screencapture -x /tmp/wa_search.png
# Reply with: MEDIA:/tmp/wa_search.png
# WAIT for user confirmation (WhatsApp stays visible on screen)

# 6. Click the confirmed result, then voice call via dropdown
cliclick c:197,$RESULT_Y
sleep 1
cliclick c:1364,53   # ← Open call dropdown
sleep 0.8
cliclick c:1350,80   # ← 語音通話 (voice); use 1350,100 for 視訊通話 (video)
```

### ⚠️ MANDATORY: Pin WhatsApp window frame first

All WhatsApp coordinates below assume a **fixed window frame**. Run this
at the start of every automation session to prevent coordinate drift:
```bash
osascript << 'EOF'
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
```
WhatsApp may cap height to ~796 — that's fine, the X-axis and top-area
coords stay stable. All scripts in `wa_helpers.sh` call `wa_activate`
which does this automatically.

### WhatsApp coordinate reference (window pinned 1440×875, as of 2026/06)
| Element | Screen Point (x, y) |
|---------|---------------------|
| Search box | Cmd+F to open, then type (NOT click) |
| Search result rows | Row N: **y = 197 + (N-1) × 68** ⚠️ |
| Search result click X | 197 (sidebar center) |
| 📞 Call dropdown icon | **(1364, 53)** — opens menu |
| → 語音通話 (voice) | **(1350, 80)** |
| → 視訊通話 (video) | **(1350, 100)** |
| Message input field | **(850, 795)** center of input bar (window height 796) |
| 🔴 Hang-up | **Close call window's traffic-light ×** (dynamic, see below) |
| Post-call: 取消 | (548, 599) |
| Post-call: 傳送訊息 | (696, 599) |
| Post-call: 重撥 | (839, 599) |

**⚠️ Search result "對話" section header pushes rows down.** The old formula
`y = 148 + (N-1) × 66` is WRONG. Correct: `y = 197 + (N-1) × 68`.

**✅ Preferred: AX-pick by name (`wa_pick.scpt` / `wa_pick_chat_by_name`).**
WhatsApp chat/search rows are **AXButtons whose description is the contact name**,
so the scripts now click the row matching the name EXACTLY via Accessibility —
no pixel row coords, no result_index. It clicks only when EXACTLY ONE row matches;
if the name collides with the self-chat (two "Alice" rows) it returns
"ambiguous" and the caller falls back to the vision-gated `wa_click_result`.
(LINE rows are NOT AX-readable — all `AXUnknown` — so LINE stays vision-only.)

**⚠️ Search result ORDER IS UNSTABLE** (fallback path only). The same query
("Alice") returns different row order depending on recent activity; self-chat
"Alice (你)" can be #1 or #2. So when AX-pick is ambiguous, **never hardcode
result_index** — use vision to identify the row, or URL scheme (bypasses search).

**⚠️ Search result click X must be in the LEFT sidebar (x≈197), NOT the chat area.**
Clicking too far right (x>350) lands in the chat pane, not the search results list.
If the search-result click lands on the wrong chat (e.g. a group "Ai" instead of
"Alice"), the x-coordinate is likely wrong — the click hit the previously-open
chat in the right pane instead of the search result row in the left sidebar.

### Key pitfalls — WhatsApp calling

**Call icon is a DROPDOWN, not a direct button (2026/06):**
Clicking the call icon at (1364, 53) opens a dropdown with 語音通話 (1350, 80)
and 視訊通話 (1350, 100). You must click TWICE: icon → menu item.
The old single-click at (746, 55) is WRONG and hits empty space.

**Hanging up — close the call window via traffic-light button:**
The in-window red hang-up button coordinates are unreliable. Instead,
**find the non-main window** and close it via its traffic-light × button:
```applescript
-- Find call window: any window whose width ≠ 1440 (the pinned main width)
tell application "System Events"
  tell process "WhatsApp"
    set frontmost to true
    repeat with w in (every window)
      set sz to size of w
      if (item 1 of sz) is not 1440 then
        perform action "AXRaise" of w
        set p to position of w
        -- Close button at origin + (8, 7)
        return {(item 1 of p) + 8, (item 2 of p) + 7}
      end if
    end repeat
  end tell
end tell
```
Then `cliclick c:X,Y` with the returned coordinates.
⚠️ Old detection used `height < 700` — this is WRONG because WhatsApp
caps main window height to ~796 which can be < 700 in some configs.
Use `width ≠ 1440` (the pinned main width) instead.

**Call window is SEPARATE from main window:**
WhatsApp opens a second window for calls. The hang-up button is in THIS
window. You MUST `AXRaise` the call window before clicking hang-up.
⚠️ Window name has a hidden LTR mark (U+200E) — string matching FAILS.
Use size comparison instead of name matching.

**If no second window appears after calling:** The call went unanswered
or failed. WhatsApp logs "語音通話 / 無人接聽" in the chat and returns to
single-window state. No hang-up needed.

**Search result row positions are UNSTABLE:**
Row positions shift based on recent call/chat activity. Self-chat
"Name (你)" can swap positions with the real contact between sessions.
Always use vision to identify the correct row, or use `wa_helpers.sh`
functions which source from `wa_search_row_y()`.

**Escape after clicking a search result can navigate AWAY from the chat:**
If you Escape after entering a chat from search, WhatsApp may jump to
a completely different chat (the previously active one). Don't Escape
between clicking a search result and performing the action (call/message).
Only Escape AFTER the action is complete.

---

## Post-action cleanup (ALWAYS — user has corrected this MULTIPLE times)

**THIS IS THE #1 SOURCE OF ERRORS.** Forgetting to exit the chat after an
operation leaves a chat/group open. The next operation then interacts with
the WRONG chat — including accidentally calling the wrong person or group.

**⚠️ CORRECT behaviour after sending a message:**
- Press **Escape** to close the chat and return to the chat list (keeps WhatsApp open and visible)
- Do NOT use Cmd+H to hide the entire app — user wants WhatsApp to stay open, just not stuck in a specific chat

**After making a call:**
- Hang up first, then Escape back to chat list

**After checking for replies:**
- Escape back to chat list

**⚠️ WhatsApp exception — do NOT hide during search-confirm-call flow:**
WhatsApp clears search results on hide. If you hide after searching and
before the user confirms which result, the results are gone on reopen and
you'll click the wrong person. Keep WhatsApp visible during the
search → confirm → click → call sequence. Only hide AFTER the call ends.

**LINE has no such issue** — LINE preserves search results across hide/show.
You CAN hide LINE while waiting for user confirmation.

```bash
# LINE:
osascript -e 'tell application "System Events" to tell process "LINE" to keystroke "h" using command down'

# WhatsApp:
osascript -e 'tell application "System Events" to tell process "WhatsApp" to keystroke "h" using command down'
```

**Pitfall — `set visible to false` can timeout during active calls.** Use
`Cmd+H` (keystroke "h" using command down) as the primary method.

## Sending a file attachment (LINE)

Use `line_file.sh` or call `line_attach_file()` from `line_helpers.sh`. The flow
(same wrong-file-proof method as WhatsApp — see "File send" above):

1. Stage the file in **`~/Downloads`** (original name, or a unique name if that
   would clobber an existing file).
2. Click the paperclip (📎) at `(402, 802)` — opens the macOS open panel.
3. `panel_select.scpt LINE 下載項目 <filename>` — AX-navigates to Downloads and
   selects the row matching the filename **exactly**. Returns `OK` / `ERR:`.
4. On `ERR:` → Escape + ABORT (never sends a wrong file).
5. Press Return → LINE sends the file. Remove the staged file afterward.

⚠️ **Do NOT use Cmd+Shift+G / `cliclick t:` to type a path.** The old flow did
that and could land on a stale folder → silent wrong-file send. LINE's open panel
here is a `sheet 1 of window 1` of the **LINE** process (not the XPC service), and
its sidebar + file rows are AX-readable, so `panel_select.scpt` selects by name
deterministically — no typing, no coordinates.

**Pitfall — `open -a Line /path/to/file`**: This triggers a QR-code popup ("LINE應用程式專用功能 請用手機掃描"), NOT a file send. Never use this approach.

## LINE Search — Finding a Contact by Name

**Preferred method — AX `set value` (bypasses input method issues):**
```applescript
tell application "System Events"
  tell process "LINE"
    tell window "LINE"
      tell splitter group 1
        set value of text field 1 to "search term"
      end tell
    end tell
  end tell
end tell
```

**Pitfall — `Cmd+A` + `keystroke` appends instead of replaces in LINE search:**
`keystroke "a" using command down` followed by `keystroke "new text"` does NOT
clear the field first — LINE's search box ignores the select-all, so each run
appends more text. Always use `cliclick tc:X,Y` (triple-click) + `key code 51`
(delete) before typing.

## WhatsApp URL Scheme (recommended for known contacts' messages/files)

The most reliable way to send a WhatsApp message — bypasses search,
coordinate issues, and modals entirely:

```bash
open "whatsapp://send?phone=886912345678&text=你的訊息"
sleep 1.5
# WhatsApp opens with the chat pre-selected and text pre-filled
# Just press Enter to send
osascript -e 'tell application "System Events" to tell process "WhatsApp" to key code 36'
```

- `phone` = full number with country code, no `+` or spaces (e.g. `886912345678`)
- `text` = URL-encoded message (spaces as `%20` or `+`)
- Works even if WhatsApp was hidden
- **Requires knowing the phone number**

**⚠️ SELF-CHAT PITFALL:** If you use the USER'S OWN phone number, the URL
scheme opens the self-chat ("You"/"你") NOT the intended contact. URL scheme
only works for OTHER people. For contacts whose phone number you don't have
(or is the same as the user's), you MUST use the search-based flow instead.

For URL-encoding the message in bash:
```bash
MSG="測試訊息"
ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$MSG")
open "whatsapp://send?phone=886912345678&text=$ENCODED"
```

## Pitfalls

- **WhatsApp window size/position changes break all hardcoded coordinates** —
  Use `wa_activate` (from `wa_helpers.sh`) which pins the window to a fixed
  frame `{0, 25, 1440, 875}` at the start. All coordinate constants in helpers
  are calibrated for this frame. If you don't use helpers, pin the window
  manually before any coordinate-based operation.
- **Escape after clicking a search result navigates to wrong chat** —
  When you click a search result to open a chat, then press Escape, WhatsApp
  doesn't go back to the chat list — it jumps to the PREVIOUSLY active chat.
  This means the next action (send message, call) hits the wrong person.
  Only Escape AFTER completing the intended action in the opened chat.
- **Clicking near chat messages triggers links** — the "端對端加密保護" text at the bottom of a chat is a clickable URL. Clicking near it opens Chrome to whatsapp.com/security. The input field is at the very bottom edge of the window, BELOW this link.
- **WhatsApp popup ads / banners silently break automation** — WhatsApp
  occasionally shows promotional popups or update banners that cover the
  chat area. The automation script will report success (exit 0) but the
  message never actually sends because clicks land on the popup instead.
  **For critical messages, always screenshot-verify after sending.** For
  cron jobs, prefer `no_agent=false` (LLM mode) with a screenshot
  verification step over `no_agent=true` (blind script) so the agent can
  detect and dismiss popups before sending.
- **WhatsApp encryption privacy popup ("你的對話和通話均受隱私保護")** —
  This full-screen modal appears when opening a chat for the first time
  in a while, or after WhatsApp updates. It has an **X button at ~(590,140)
  screen points**. It blocks the entire chat area including the input field.
  The script will "succeed" (exit 0) but the message won't send because
  `cliclick c:540,740` hits the popup body instead of the input field.
  **Dismiss procedure:** `cliclick c:590,140` then `sleep 0.5` before
  proceeding. In automated scripts, add a pre-check: screenshot + vision
  to detect the popup, or always attempt a dismiss click at (590,140) as
  a no-op safety step (clicking empty space is harmless if no popup).
- **Vision returns retina pixels, cliclick uses screen points** — On Retina
  displays the screenshot is 2× the logical resolution (e.g. 2880×1800 for a
  1440×900 screen). Vision coordinates from the image must be **divided by 2**
  before passing to `cliclick`. Forgetting this is the #1 cause of "click
  didn't register" on LINE/WhatsApp automation.
- **File picking is AX-only now — don't type paths into the open panel.** Both
  apps' open panels are `sheet 1 of window 1` with AX-readable sidebar + file
  rows; `panel_select.scpt` navigates and selects by exact filename. The old
  Cmd+Shift+G / `cliclick t:` path-typing is removed (it caused silent wrong-file
  sends). See "File send" near the top.
- **`Cmd+V` / `keystroke` unreliable for LINE** — Focus jumps between cliclick
  and the keystroke. Always use `AXFocusedUIElement` + `set value` instead.
- **Double-nested `tell process` causes `-1728`** — Never write
  `tell process "LINE" … set f to … of process "LINE"` inside a
  `tell application "System Events"` block.
- **WhatsApp AX tree** — WebView makes it 7+ levels deep. Never path-traverse
  to find the text area; use `AXFocusedUIElement` after clicking.
- **LINE popup mode hides chat list** — Always expand with `click button 3`
  before navigating.
- **`key code 36`** is more reliable than `keystroke return` for sending.
- **Script permission resets on write:** `skill_manage(action='write_file')` overwrites the file and loses `+x`. Always `chmod +x` after writing scripts.
- **LINE toolbar icons are invisible to AX**: Use known coordinates or
  screenshot+vision; don't waste time probing AX for them.
- **String `&` in shell AppleScript `-e` or heredoc** — Shell interprets `&` as
  backgrounding. Use heredoc with **single-quoted delimiter**: `osascript << 'EOF'`.
  Even inside heredoc, AppleScript string concatenation with `&` can fail if
  the heredoc delimiter isn't single-quoted. Also: AppleScript `return X & "," & Y`
  produces extra commas. Cast to string first: `(X as string) & "," & (Y as string)`.
  Safest: write `.scpt` file and run with `osascript /tmp/script.scpt`.
  **Hermes `terminal()` is even stricter** — it scans the entire command for `&`
  and rejects it as "backgrounding" even inside heredocs/strings. Workaround:
  write the AppleScript to a `.scpt` file via `write_file`, then run
  `osascript /tmp/script.scpt`. This also avoids all quoting hell.

## Reusable scripts

All WhatsApp scripts source `~/.hermes/scripts/wa_helpers.sh`; all LINE scripts
source `~/.hermes/scripts/line_helpers.sh`. Both live in the skill's `scripts/`
dir with symlinks from `~/.hermes/scripts/`.

**WhatsApp helpers** (`wa_helpers.sh`):
- `wa_activate` — open, activate, pin window frame, dismiss popups
- `wa_search <name>` — Cmd+F, clear, type name
- `wa_pick_chat_by_name <name>` — AX-click the row matching the name exactly
  (preferred; returns nonzero if ambiguous/not-found → caller falls back)
- `wa_click_result <N>` — click Nth search result row (vision-gated fallback)
- `wa_start_call [voice|video]` — dropdown → menu item click
- `wa_hangup` — find call window (width≠1440) → close via traffic light
- `wa_get_phone <name>` — contact → phone number lookup
- `wa_escape` — Escape back to chat list
- `wa_screenshot <path>` — retina screenshot resized to 1400px for Telegram

**LINE helpers** (`line_helpers.sh`):
- `line_activate` — open, activate, pin window to {0,30}/{1440,794}
- `line_search <name>` — AX set value on search field (CJK-safe)
- `line_click_result <N>` — click Nth search result row
- `line_send_text` — click input via AX position, set value from clipboard, Enter
- `line_start_call [voice|video]` — phone icon dropdown → menu item → confirm
- `line_hangup` — Escape → confirm dialog → Enter
- `line_attach_file <file_path>` — 📎 → `panel_select.scpt` (AX pick by name) → send
- `line_hide` — Cmd+H
- `line_shot <label>` — screencapture with timestamped filename
- `line_log <msg>` — prefixed log output

### `scripts/wa_helpers.sh` — Shared WhatsApp helper functions
```bash
# Source at the top of any wa_*.sh script:
source "$(cd "$(dirname "$0")" && pwd)/wa_helpers.sh"
# Coordinates and phone numbers are centralized here.
# Edit wa_helpers.sh to add contacts or update coords.
```

### `scripts/line_helpers.sh` — Shared LINE helper functions
```bash
# Source at the top of any line_*.sh script:
source "$(cd "$(dirname "$0")" && pwd)/line_helpers.sh"
# Provides: line_activate, line_search, line_click_result, line_send_text,
# line_start_call, line_hangup, line_attach_file, line_hide, line_shot, line_log.
# Coordinates and window geometry are centralized here.
# Edit line_helpers.sh to update coords or add features.
```
ℹ️ **File picking uses `panel_select.scpt` (AX), not Go-to-folder typing.** See
the "File send" section near the top for the wrong-file-proof flow.

### `scripts/line_call.sh` — LINE voice call (vision-gated, NOT blind no_agent)
```bash
~/.hermes/scripts/line_call.sh <contact_name> [hang_up_seconds] [result_index] [voice|video]
# Sources line_helpers.sh. Searches via AX set value, clicks result row,
# opens the call dropdown → 語音通話, post-verifies with a screenshot.
```
⚠️ **LINE has no URL scheme** — you cannot open a chat by number the way
WhatsApp does, so there is no safe way to bypass search. Therefore a LINE call
ALWAYS carries wrong-person risk and **must be vision-gated**: screenshot the
search results → confirm the chat title is the intended person → THEN call.
**Do NOT run `line_call.sh` blindly in a `no_agent=true` cron** (see the call
section's mandatory human-in-the-loop rule). `result_index` exists only for the
interactive flow AFTER a human/vision has confirmed which row is correct.

### `scripts/wa_call.sh` — WhatsApp voice/video call (URL scheme preferred)
```bash
~/.hermes/scripts/wa_call.sh <contact_name> [hang_up_seconds] [voice|video] [result_index]
# URL scheme if phone known → opens correct chat, then call dropdown.
# Falls back to search if no phone number.
# ⚠️ Search fallback: result order UNSTABLE — vision-verify for ambiguous names.
```

### `scripts/wa_msg.sh` — WhatsApp message (URL scheme preferred, search fallback)
```bash
~/.hermes/scripts/wa_msg.sh <contact_name> <message> [result_index]
# URL scheme if phone known → safest (no search, no wrong-person risk).
# Falls back to search + click result if no phone number.
# ⚠️ Search fallback: result order UNSTABLE — vision-verify for ambiguous names.
```

### `scripts/wa_file.sh` — WhatsApp file send (URL scheme preferred, search fallback)
```bash
~/.hermes/scripts/wa_file.sh <contact_name> <file_path> [result_index] [caption]
# URL scheme if phone known, search fallback otherwise.
# Attach via + → 檔案, then panel_select.scpt picks the file by exact name (AX).
# Aborts (no send) if the name isn't found. Optional caption before sending.
```
⚠️ **The old clipboard mechanism (`set the clipboard to POSIX file` + Cmd+V)
does NOT work** — WhatsApp's Electron app ignores a POSIX-file clipboard paste.
⚠️ **The Cmd+Shift+G path-typing flow was also removed** — WhatsApp's panel
ignored the shortcut and silently sent the wrong file. Now uses the AX
`panel_select.scpt` picker (see "File send" up top). Same known-phone limitation
as `wa_msg.sh`.

### `scripts/line_file.sh` — LINE file send (vision-gated, NO URL scheme)
```bash
~/.hermes/scripts/line_file.sh <contact_name> <file_path> [result_index]
# Sources line_helpers.sh. Searches, screenshots for vision title-confirm,
# opens chat, clicks 📎, then line_attach_file() → panel_select.scpt picks the
# file by exact name (AX) and sends. Aborts (no send) if the name isn't found.
```
⚠️ LINE has no URL scheme, so the search-result title MUST be vision-confirmed
(the echoed `MEDIA:` before-screenshot) before attaching. Not cron-safe blind.
⚠️ The 8MB quote-template xlsx files send fine — LINE has no file size issue for
files up to at least ~8MB.

### LINE message send (inline, no script) — verified working flow
When the agent needs to send a LINE message without a dedicated script, this is
the proven pattern (avoids the `-1728` double-nested process error and the
Hermes terminal `&` rejection):
```bash
# 1. Search + click contact (same as file send)
# 2. Copy message to clipboard
cat << 'MSGEOF' | pbcopy
Your message here (CJK safe, multi-line OK)
MSGEOF

# 3. Click input field
cliclick c:908,748

# 4. Write setvalue script (avoids & in shell + double-nested tell)
# Use write_file to create /tmp/line_setvalue.scpt:
#   tell application "System Events"
#     set f to value of attribute "AXFocusedUIElement" of process "LINE"
#     if class of f is text area then
#       set value of f to (the clipboard as text)
#     end if
#   end tell
osascript /tmp/line_setvalue.scpt

# 5. Send
osascript -e 'tell application "System Events" to tell process "LINE" to key code 36'
```
⚠️ The `-1728` error: `set f to ... of process "LINE"` must be at the TOP level
of `tell application "System Events"`, NOT nested inside `tell process "LINE"`.
The correct form is `set f to value of attribute "AXFocusedUIElement" of process "LINE"`
directly under `tell application "System Events"` — never wrap it in another
`tell process "LINE"` block.

### `~/.hermes/scripts/send_msg.sh` — Send a message to the focused chat
```bash
send_msg.sh line "早安！"
send_msg.sh whatsapp "Morning!"
# Note: must have the correct chat already open/focused before calling
```

### ⚠️ CRITICAL: Preventing wrong-person calls/messages

**This is the #1 problem with WhatsApp automation.** Two failure modes:

1. **URL scheme + own phone number → self-chat.** `wa_msg.sh` uses phone
   numbers. If the user's own number is in the contact list, it opens the
   self-chat ("You"/"你") instead of the actual contact. Keep your own
   number OUT of the curated table in `wa_helpers.sh` to prevent this.

2. **Search result order is UNSTABLE.** "Alice" returns self-chat as
   #1 or #2 depending on recent activity. Hardcoding `result_index` WILL
   eventually hit the wrong person.

**MANDATORY: Vision-verify before EVERY search-based action (call, message, file).**

**Decision matrix — which method to use:**

All scripts auto-detect: URL scheme first (if phone in `wa_curated_phone`),
search fallback if no number. The scripts handle this internally.

| Action | Has phone# (not user's own) | No phone# / user's own # |
|--------|----------------------------|-----------------------------|
| 💬 Send msg | `wa_msg.sh` → URL scheme auto | `wa_msg.sh` → search fallback + **vision verify** |
| 📎 Send file | `wa_file.sh` → URL scheme auto | `wa_file.sh` → search fallback + **vision verify** |
| 📞 Call | `wa_call.sh` → URL scheme → chat → dropdown | `wa_call.sh` → search fallback + **vision verify** → dropdown |

**⚠️ CRITICAL: `keystroke` vs `pbcopy+Cmd+V` (2026/06 root cause fix)**
AppleScript `keystroke "text"` goes through the macOS input method. When a CJK
input method (注音, 拼音, etc.) is active, English characters and paths become
FULL-WIDTH (全型) → silently breaks all path navigation, search queries, URLs.
**Always use `printf '%s' "text" | pbcopy` then `keystroke "v" using command down`
for any text that must be ASCII-exact.** All wa_*.sh and line_file.sh scripts
have been updated to use this pattern (2026/06).

**Why calls can't just use URL scheme end-to-end:**
`whatsapp://call?phone=PHONE` does NOT work on macOS desktop. Only
`whatsapp://send` works. So for known-phone contacts, we use URL scheme
to reliably OPEN the correct chat (no search, no wrong-person risk),
then click the call dropdown from inside that chat.

**Vision-verified flow (used by agent via delegate_task):**
```python
# Step 1: Activate and search
wa_activate()
wa_search("Contact Name")

# Step 2: Screenshot and vision-analyze
screencapture -x /tmp/wa_search.png
# vision_analyze the screenshot:
#   "列出所有搜尋結果，哪一個是 [Name] 聯絡人（不是「你」）？
#    給我該 row 的 retina pixel Y center，除以 2 得到 screen point Y"

# Step 3: Click the VERIFIED row (never guess!)
cliclick c:197,<verified_y>

# Step 4: Verify chat header shows correct name (optional but recommended)
screencapture → vision: "聊天室標題是誰？有沒有 (你) 或 商業帳號？"

# Step 5: Perform action (call / send message / send file)
```

**For cron/scheduled jobs:**
- **Safe (no_agent=true):** Only for contacts with ONE unique search result
  AND a known phone number (e.g. "mong7" → `wa_msg.sh`).
- **Ambiguous names:** MUST use `no_agent=false` (LLM mode) with vision
  verification in the prompt. Never schedule blind search-based operations.

### `scripts/wa_send.sh` — ❌ REMOVED (was deprecated, unreliable)
Hardcoded coordinates (old 148/66 result rows, 540/740 input) + no popup
handling → reported exit 0 while sending nothing. **Removed 2026/06**, moved
to `scripts/_deprecated/`. Use instead:
- **Send to a known number:** `wa_msg.sh` (URL scheme — safest)
- **Send to the already-open chat:** `send_msg.sh whatsapp "…"` (set value, works)
- **Search + send (ambiguous name):** vision-verify the row, then `send_msg.sh`

### Cron job pattern for scheduled calls
**⚠️ LINE scheduled calls MUST be `no_agent=false` (LLM + vision).** LINE has no
URL scheme, so there is no wrong-person-proof blind path. Schedule an LLM job
that searches, screenshots, vision-confirms the chat title, and only then calls:
```
cronjob(action='create', schedule='2026-06-20T09:00:00', no_agent=false,
        prompt='Open LINE, search "contact_name", screenshot the results, '
               'vision-confirm which row title is exactly contact_name (NOT a '
               'group, NOT a similar name). Then run line_call.sh "contact_name" '
               '10 <that row index>. Screenshot to confirm the call connected.',
        skills=['macos-messaging'], name='Call contact_name')
```
**WhatsApp** scheduled calls to a KNOWN phone number can use the URL scheme to
open the right chat first (no search), which is wrong-person-proof; only the
call-dropdown click is coordinate-based.

### Cron job pattern for scheduled messages

**See also:** `references/erp-quote-workflow.md` — ERP quote export → LINE file send workflow (primary business use case).

**⚠️ Prefer LLM mode (`no_agent=false`) for WhatsApp scheduled messages**
so the agent can detect and dismiss popups before sending:
```
cronjob(action='create', schedule='2026-06-20T09:00:00',
        prompt='Open WhatsApp, search "Alice", click first result, screenshot to verify no popups blocking the chat. If there is a popup/banner, dismiss it (click X or Escape). Then send the message "早安" using pbcopy + Cmd+V + key code 36. Screenshot to verify the message was sent. Hide WhatsApp.',
        skills=['macos-messaging'],
        name='WA msg Alice 早安')
```
For low-risk / known-clean contacts with a known phone number, `no_agent=true`
with the URL-scheme script is fine (wa_msg.sh, NOT the removed wa_send.sh):
```
cronjob(action='create', schedule='...', no_agent=true,
        script='wa_msg.sh "Alice" "早安"',
        name='WA msg Alice')
```
⚠️ Never schedule a blind coordinate-based send. URL scheme (wa_msg.sh) is the
only `no_agent=true`-safe path because it bypasses search/coords/modals.
