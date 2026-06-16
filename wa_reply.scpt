-- wa_reply.scpt <text_substring>
-- Find the WhatsApp message bubble whose AX description contains <text_substring>
-- (and looks like a real bubble — carries a time / delivery marker) and print a
-- right-click point ON the bubble as "x,y". Sent bubbles ("你的…") are right-
-- aligned so we aim at the right side of the row; received bubbles at the left.
-- The caller right-clicks this point, then navigates the menu by KEYBOARD
-- (Down → Enter selects the top item「回覆」) — no pixel menu click, no screenshot.
--
-- FAIL CLOSED on ambiguity: a reply quotes ONE message, so if more than one
-- DISTINCT visible message matches the substring we return "ERR: ambiguous"
-- rather than guessing the first hit. (AX exposes each bubble as nested nodes
-- with the same description, so we dedupe by description text before counting.)
on run argv
  set needle to item 1 of argv
  tell application "System Events"
    tell process "WhatsApp"
      set allE to entire contents of window 1
      set seenDescs to {}
      set firstPt to ""
      repeat with e in allE
        try
          set d to description of e
          if d is not missing value and d contains needle then
            if (d contains "上午" or d contains "下午" or d contains "已傳送給" or d contains "已讀" or d contains "已送達") then
              if seenDescs does not contain d then
                set end of seenDescs to d
                if firstPt is "" then
                  set p to position of e
                  set sz to size of e
                  set rowX to item 1 of p
                  set rowW to item 1 of sz
                  set cy to (item 2 of p) + ((item 2 of sz) / 2)
                  if d starts with "你的" or d contains "已傳送給" then
                    set cx to rowX + rowW - 140
                  else
                    set cx to rowX + 140
                  end if
                  set firstPt to ((cx as integer) as text) & "," & ((cy as integer) as text)
                end if
              end if
            end if
          end if
        end try
      end repeat
      if (count of seenDescs) is 1 then
        return firstPt
      else if (count of seenDescs) is 0 then
        return "ERR: bubble not found for '" & needle & "'"
      else
        return "ERR: ambiguous (" & (count of seenDescs) & " visible messages match '" & needle & "') — use a more unique substring"
      end if
    end tell
  end tell
end run
