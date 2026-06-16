-- wa_chats.scpt [count]
-- List the WhatsApp chat-list entries (names) as TEXT via Accessibility.
-- Each chat row is an AXButton whose description is the chat/contact/group name
-- (width ~274; the search box button is ~254 and is skipped). Returns the top
-- [count] (default 15) visible chats, top to bottom. Plain text — no vision.
-- Note: unread counts are not reliably exposed in AX, so only names are listed.
on run argv
  set maxN to 15
  try
    set maxN to (item 1 of argv) as integer
  end try
  tell application "System Events"
    tell process "WhatsApp"
      set out to ""
      set n to 0
      set allE to entire contents of window 1
      repeat with e in allE
        try
          if role of e is "AXButton" then
            set sz to size of e
            if (item 1 of sz) ≥ 260 and (item 1 of sz) ≤ 300 then
              set d to ""
              try
                set d to description of e
              end try
              if d is not "" and d is not missing value then
                set out to out & "• " & d & linefeed
                set n to n + 1
                if n ≥ maxN then exit repeat
              end if
            end if
          end if
        end try
      end repeat
      if out is "" then return "(no chats read — is WhatsApp showing the chat list?)"
      return out
    end tell
  end tell
end run
