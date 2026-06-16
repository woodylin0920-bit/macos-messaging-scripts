#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# send_msg.sh — 傳訊息到 LINE 或 WhatsApp
# 用法: ./send_msg.sh [line|whatsapp] "訊息內容"
#
# 依賴: cliclick (brew install cliclick)

APP=$1
MSG=$2

if [ -z "$APP" ] || [ -z "$MSG" ]; then
  echo "用法: $0 [line|whatsapp] '訊息內容'"
  exit 1
fi

if [ "$APP" = "line" ]; then
  PROCESS="LINE"
  open -a LINE
elif [ "$APP" = "whatsapp" ]; then
  PROCESS="WhatsApp"
  open -a WhatsApp
else
  echo "不支援的 App: $APP（支援 line / whatsapp）"
  exit 1
fi

sleep 1.0

# 把訊息放進 clipboard
printf '%s' "$MSG" | pbcopy

# Activate app
osascript -e "tell application \"$PROCESS\" to activate"
sleep 0.5

# 取 AXFocusedUIElement 並 set value
osascript << OSASCRIPT
tell application "System Events"
  set f to value of attribute "AXFocusedUIElement" of process "$PROCESS"
  if class of f is text area then
    set value of f to (the clipboard as text)
  else
    error "Focus 不在 text area，請先點擊輸入框"
  end if
end tell
OSASCRIPT

sleep 0.5

# Enter 送出
osascript -e "tell application \"System Events\" to tell process \"$PROCESS\" to key code 36"

echo "✅ 訊息已送出到 $PROCESS"
