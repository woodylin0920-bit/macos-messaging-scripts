-- panel_select.scpt <process> <sidebar_label> <filename>
-- Robustly pick a file in a macOS NSOpenPanel by:
--   1. clicking the named sidebar entry (e.g. "下載項目" / "桌面") to navigate, then
--   2. selecting the file ROW whose name matches <filename> exactly via AX.
-- It does NOT click "Open"/send — the caller presses Return (the default button)
-- only after this returns "OK". If the sidebar entry or the file can't be found
-- it returns an "ERR: ..." string so the caller can ABORT without sending the
-- wrong file. This replaces the fragile Cmd+Shift+G + Down + Enter dance, which
-- could silently select whatever file the panel happened to be sitting on.
on run argv
  set procName to item 1 of argv
  set sbLabel to item 2 of argv
  set fname to item 3 of argv
  tell application "System Events"
    tell process procName
      set frontmost to true
      try
        set sh to sheet 1 of window 1
      on error
        return "ERR: no open-panel sheet on " & procName
      end try

      -- 1) Navigate via the sidebar entry.
      -- The open-panel sidebar must be visible (it is by default). If a user has
      -- hidden it, try toggling it back on (Cmd+Opt+S, the standard sidebar
      -- toggle) once, then look again.
      set navOk to false
      set sidebarSeen to false
      repeat with attempt from 1 to 2
        try
          set sb to outline 1 of scroll area 1 of splitter group 1 of sh
          set sidebarSeen to true
          repeat with rw in rows of sb
            set lbl to ""
            try
              set lbl to value of static text 1 of UI element 1 of rw
            end try
            if lbl is sbLabel then
              select rw
              set navOk to true
              exit repeat
            end if
          end repeat
        end try
        if navOk then exit repeat
        if not sidebarSeen and attempt is 1 then
          -- sidebar likely hidden → toggle it on and retry
          keystroke "s" using {command down, option down}
          delay 0.6
        end if
      end repeat
      if not navOk then
        if not sidebarSeen then return "ERR: open-panel sidebar not available — show it in the panel (View ▸ Show Sidebar) and retry"
        return "ERR: sidebar '" & sbLabel & "' not found"
      end if
      delay 1.0

      -- Force LIST view (Cmd+2). NSOpenPanel persists its last view; in icon /
      -- column / gallery view the `outline 1` file list below is absent and every
      -- send would abort. Cmd+2 switches to list view where the AX path exists.
      keystroke "2" using command down
      delay 0.6

      -- 2) Select the file row whose name matches exactly
      set fileFound to false
      try
        set fo to outline 1 of scroll area 1 of splitter group 1 of splitter group 1 of sh
        repeat with rw in rows of fo
          set vv to ""
          try
            repeat with c in (UI elements of rw)
              try
                if role of c is "AXTextField" then
                  set vv to value of c
                else
                  set vv to value of text field 1 of c
                end if
              end try
              if vv is fname then exit repeat
            end repeat
          end try
          if vv is fname then
            select rw
            set fileFound to true
            exit repeat
          end if
        end repeat
      end try
      if not fileFound then return "ERR: file '" & fname & "' not visible in panel"
      delay 0.3
      return "OK"
    end tell
  end tell
end run
