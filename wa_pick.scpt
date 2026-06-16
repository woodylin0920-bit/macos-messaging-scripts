-- wa_pick.scpt <contact_name>
-- Click the WhatsApp chat-list / search-result row whose name matches EXACTLY,
-- via Accessibility (rows are AXButtons whose description is the contact name).
-- This makes the search fallback pick the right person WITHOUT brittle pixel row
-- coords and WITHOUT the unstable-result-order wrong-person risk.
-- Returns:
--   "OK"                exactly ONE row matched the name → clicked it
--   "ERR: none ..."     no row matched
--   "ERR: ambiguous ..." more than one row matched (e.g. a name that collides
--                        with the self-chat) — caller must NOT guess
-- On any ERR the caller falls back to the vision-gated flow (NOT a blind click).
-- AX text values inside Electron rows are unreadable, so we deliberately match
-- ONLY on the exact name and refuse to guess when there is more than one hit.
on run argv
  set targetName to item 1 of argv
  tell application "System Events"
    tell process "WhatsApp"
      set frontmost to true
      set allE to entire contents of window 1
      set hits to {}
      repeat with e in allE
        try
          if role of e is "AXButton" then
            set sz to size of e
            if (item 1 of sz) ≥ 240 and (item 1 of sz) ≤ 300 then
              set d to ""
              try
                set d to description of e
              end try
              if d is targetName then set end of hits to e
            end if
          end if
        end try
      end repeat
      if (count of hits) is 1 then
        click (item 1 of hits)
        return "OK"
      else if (count of hits) is 0 then
        return "ERR: none matched '" & targetName & "'"
      else
        return "ERR: ambiguous (" & (count of hits) & ") for '" & targetName & "'"
      end if
    end tell
  end tell
end run
