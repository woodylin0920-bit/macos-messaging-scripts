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
-- rather than guessing. AX exposes each bubble as several nested nodes that share
-- the same description AND the same vertical position, so we dedupe by VERTICAL
-- POSITION (a y-bucket), not by description text. That way two genuinely separate
-- messages with identical text (different rows → different y) are still counted
-- as two and trip the ambiguity guard.
on run argv
  set needle to item 1 of argv
  tell application "System Events"
    tell process "WhatsApp"
      set allE to entire contents of window 1
      set seenY to {}
      set firstPt to ""
      repeat with e in allE
        try
          set d to description of e
          if d is not missing value and d contains needle then
            if (d contains "上午" or d contains "下午" or d contains "已傳送給" or d contains "已讀" or d contains "已送達" or d contains ":0" or d contains ":1" or d contains ":2" or d contains ":3" or d contains ":4" or d contains ":5") then
              set p to position of e
              set sz to size of e
              set rowX to item 1 of p
              set rowW to item 1 of sz
              set cyRaw to (item 2 of p) + ((item 2 of sz) / 2)
              set yBucket to (round (cyRaw / 25))
              if seenY does not contain yBucket then
                set end of seenY to yBucket
                if firstPt is "" then
                  if d starts with "你的" or d contains "已傳送給" then
                    set cx to rowX + rowW - 140
                  else
                    set cx to rowX + 140
                  end if
                  set firstPt to ((cx as integer) as text) & "," & ((cyRaw as integer) as text)
                end if
              end if
            end if
          end if
        end try
      end repeat
      if (count of seenY) is 1 then
        return firstPt
      else if (count of seenY) is 0 then
        return "ERR: bubble not found for '" & needle & "'"
      else
        return "ERR: ambiguous (" & (count of seenY) & " visible messages match '" & needle & "') — use a more unique substring"
      end if
    end tell
  end tell
end run
