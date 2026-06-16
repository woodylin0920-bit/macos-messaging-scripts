-- wa_read.scpt [count]
-- Read the currently-open WhatsApp chat's recent messages as TEXT via
-- Accessibility. WhatsApp (Electron) exposes each bubble's content in the AX
-- description (direction + text/filename + time + delivery/read state), so no
-- screenshot or vision model is needed — the output is plain text any model can
-- read. Returns the last [count] (default 12) message lines, newest last.
on run argv
  set maxN to 12
  try
    set maxN to (item 1 of argv) as integer
  end try
  tell application "System Events"
    tell process "WhatsApp"
      set msgs to {}
      set allE to entire contents of window 1
      repeat with e in allE
        try
          set d to description of e
          if d is not missing value and d is not "" then
            if (d contains "訊息" or d contains "文件" or d contains "相片" or d contains "照片" or d contains "通話" or d contains "貼圖" or d contains "語音" or d contains "已傳送給") then
              -- real bubbles always carry a time or delivery marker; UI buttons
              -- ("撰寫訊息", "建議貼圖", "語音訊息") do not → require one.
              if (d contains "上午" or d contains "下午" or d contains "昨天" or d contains "週" or d contains "已傳送給" or d contains "已讀" or d contains "已送達") then
              if (d does not contain "端對端") and (d does not contain "的對話訊息") and (d does not contain "請使用手機版") then
                -- collapse the outer/inner duplicate AX nodes (they are adjacent)
                if (count of msgs) is 0 or (item -1 of msgs) is not d then
                  set end of msgs to d
                end if
              end if
              end if
            end if
          end if
        end try
      end repeat
      set total to count of msgs
      set startI to 1
      if total > maxN then set startI to total - maxN + 1
      set out to ""
      repeat with i from startI to total
        set out to out & "• " & (item i of msgs) & linefeed
      end repeat
      if out is "" then return "(no messages read — chat may not be open)"
      return out
    end tell
  end tell
end run
