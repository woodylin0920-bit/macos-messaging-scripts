#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# selftest.sh [wa_contact] [line_contact]
# Run the FULL WhatsApp + LINE feature matrix against a test contact and print a
# PASS/FAIL summary. Designed to be triggered by the hermes agent in one shot
# (e.g. from Telegram) — deterministic, self-contained, clean text output.
#
# Sends real messages/files and places short auto-hung-up calls to the contact,
# so point it at a test contact you own. Defaults: WhatsApp "Alice", LINE "Alice".

S="$(cd "$(dirname "$0")" && pwd)"
WA="${1:-Alice}"
LN="${2:-Alice}"
STAMP=$(date +%H%M%S)
TF="/tmp/selftest_${STAMP}.txt"
printf 'macos-messaging selftest %s\n' "$STAMP" > "$TF"

pass=0; fail=0
ok(){ echo "✅ $1"; pass=$((pass+1)); }
no(){ echo "❌ $1"; fail=$((fail+1)); }
# chk LABEL CMD... → PASS if the command exits 0
chk(){ local label="$1"; shift; if "$@" >/tmp/st_out 2>&1; then ok "$label"; else no "$label"; fi; }
# chk_out LABEL PATTERN CMD... → PASS if output exits 0 AND matches PATTERN
chk_out(){ local label="$1" pat="$2"; shift 2; if "$@" 2>/dev/null | grep -q "$pat"; then ok "$label"; else no "$label"; fi; }

echo "════ macos-messaging selftest ${STAMP} ════"
echo "WhatsApp → ${WA} | LINE → ${LN}"
echo "── WhatsApp ──"
chk     "WA 傳訊息"        "$S/wa_msg.sh"  "$WA" "🤖 selftest WA msg ${STAMP}"
chk     "WA 傳檔案"        "$S/wa_file.sh" "$WA" "$TF" "" "🤖 selftest WA file ${STAMP}"
chk     "WA 通話(撥+掛)"   "$S/wa_call.sh" "$WA" 2 voice
chk_out "WA 讀訊息"        "selftest WA msg ${STAMP}" "$S/wa_read.sh" "$WA" 6
chk_out "WA 列出聊天"      "•"             "$S/wa_list_chats.sh" 8
chk     "WA 回覆指定訊息"  "$S/wa_reply.sh" "$WA" "selftest WA msg ${STAMP}" "↩️ selftest WA reply ${STAMP}"
echo "── LINE ──"
chk     "LINE 傳訊息"      "$S/line_msg.sh"  "$LN" "🤖 selftest LINE msg ${STAMP}" 1
chk     "LINE 傳檔案"      "$S/line_file.sh" "$LN" "$TF" 1
chk     "LINE 通話(撥+掛)" "$S/line_call.sh" "$LN" 2 1 voice
chk_out "LINE 讀訊息(截圖)" "MEDIA:"        "$S/line_read.sh" "$LN" 1
chk_out "LINE 列出聊天(截圖)" "MEDIA:"      "$S/line_list_chats.sh"

rm -f "$TF" /tmp/st_out 2>/dev/null
echo "════════════════════════════════════"
echo "結果:${pass} 通過 / ${fail} 失敗(共 $((pass+fail)) 項)"
[ "$fail" -eq 0 ] && echo "🎉 全部通過" || echo "⚠️ 有項目失敗,請看上面 ❌"
