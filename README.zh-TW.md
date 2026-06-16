# macOS 通訊軟體自動化腳本

[English](README.md) · **繁體中文** · [简体中文](README.zh-CN.md)

在 macOS 上自動化 **LINE** 與 **WhatsApp** 桌面版 —— 傳訊息、傳檔案、撥語音/視訊電話、讀取與列出聊天、回覆指定訊息。設計為 [Nous Research `hermes-agent`](https://github.com/nousresearch/hermes-agent) 的 skill,也可當獨立 shell 腳本使用。

底層用 AppleScript + System Events + Accessibility (AX) + [`cliclick`](https://github.com/BlueM/cliclick) 驅動。不需第三方 API 金鑰、不用掃 QR —— 直接操作你已登入的桌面 App。

> **僅限 macOS。** 與系統 `/bin/bash` 3.2 相容。

---

## 總覽

個人 LINE/WhatsApp 訊息沒有好用的公開 API,所以這套直接操作桌面 App。設計上優先使用 Accessibility 樹(比對元件、檔名、聯絡人名、鍵盤選單),只有在 AX 無法取得時才退回像素座標。截圖是最後手段,只用在 AX 讀不到的 LINE 內容。

兩種用法:

- **作為 hermes skill** —— 放進 `~/.hermes/skills/`。`SKILL.md` 記錄了 AX 怪癖與「防打錯人/防送錯檔」規則;agent 讀 skill、呼叫腳本、操作 App。
- **作為獨立腳本** —— 直接跑任一 wrapper,例如 `./wa_msg.sh "Alice" "嗨"`。

**注意:** 這是座標 + AX 的螢幕自動化,不是官方 API。換螢幕、解析度、介面語言或 App 版本,可能需要重新校準座標(見 [校準](#校準))。

---

## 功能

`✓` 可用 · `partial` 受限/需視覺 · `planned` 尚未 · `—` 不適用

| 功能 | WhatsApp | LINE | 說明 |
|---|:---:|:---:|---|
| 傳訊息 | ✓ | ✓ | CJK 安全(`pbcopy` + AX `set value`) |
| 傳檔案 | ✓ | ✓ | AX 依精確檔名選取,不會送錯檔 |
| 語音/視訊通話 | ✓ | ✓ | 撥出,可選 N 秒後自動掛斷 |
| 讀取訊息 | ✓ 文字 | partial | WhatsApp 泡泡 AX 可讀成文字;LINE 內容為 `AXUnknown`,改回傳截圖給視覺模型 |
| 列出最近聊天 | ✓ 文字 | partial | 讓 agent 先看有誰再行動 |
| 找對聊天室 | ✓ 依名字 | partial | WhatsApp 列是 AX button;LINE 列為 `AXUnknown`(需截圖確認) |
| 群組送訊息 | ✓ | ✓ | 群組就是有名字的聊天 |
| 回覆指定訊息 | ✓ | planned | WhatsApp:AX 依文字定位泡泡 → 右鍵 → 鍵盤 ↓+Enter 選「回覆」(不靠截圖) |
| 動作後關聊天室 | ✓ | ✓ | Esc,避免 App 一直把進來的訊息標已讀 |
| 排程 | ✓ | partial | 透過 `hermes cron`;盲排只建議 WhatsApp |
| 表情回應 | planned | planned | |
| 搜尋歷史訊息 | — | — | AX 只看得到目前畫面 |

通用能力:

- **座標可校準。** 每個座標都是 `${VAR:-預設值}`,可由環境變數或 git-ignored 的 `messaging_coords.local.sh` 覆寫。`calibrate.sh` 互動式擷取,免改原始碼。
- **不只信 exit 0。** 每個動作都印出 before/after 截圖路徑(`MEDIA:`)供確認。
- **AX 優先、像素為輔。** AX 能辨識的(元件、檔名、名字、鍵盤選單)就走 AX,其餘才用像素座標。

已於 2026-06-16 在實機 LINE/WhatsApp 端到端驗證:以上全部,加上一次 hermes agent 執行與 `hermes cron` 排程(相對與絕對時間)。`selftest.sh` 跑完整 11 項矩陣並回報通過/失敗(11/11)。

---

## 需求

1. macOS,系統 `/bin/bash` 3.2(腳本已避開 `declare -A` 與 `$()` 內 heredoc)。
2. `cliclick` —— `brew install cliclick`。
3. Accessibility 權限 —— 系統設定 → 隱私權與安全性 → 輔助使用 → 加入你的終端機(或跑 hermes 的程式)。沒給會出現 `osascript 不允許輔助取用 (-25211)`。
4. LINE / WhatsApp 桌面版已安裝、登入並開著。

> 腳本點擊的介面字串是繁體中文(`檔案`、`確定要與X進行通話?` 等)。介面非中文時這些字串需調整。

---

## 安裝

作為 hermes skill:

```bash
cp -R macos-messaging-scripts ~/.hermes/skills/apple/macos-messaging
```

獨立使用:

```bash
git clone https://github.com/woodylin0920-bit/macos-messaging-scripts
cd macos-messaging-scripts && chmod +x *.sh
./calibrate.sh   # 校準座標到你的螢幕
```

---

## 用法

WhatsApp:

| 腳本 | 功能 | 範例 |
|---|---|---|
| `wa_msg.sh` | 傳訊息 | `wa_msg.sh "Alice" "嗨"` |
| `wa_file.sh` | 傳檔案 | `wa_file.sh "Alice" /tmp/a.pdf "" "說明文字"` |
| `wa_call.sh` | 撥電話 | `wa_call.sh "Alice" 5 voice`(5 秒後掛斷) |
| `wa_read.sh` | 讀訊息(文字) | `wa_read.sh "Alice" 12` |
| `wa_list_chats.sh` | 列出最近聊天 | `wa_list_chats.sh 15` |
| `wa_reply.sh` | 回覆指定訊息 | `wa_reply.sh "Alice" "要比對的文字" "回覆內容"` |

LINE:

| 腳本 | 功能 | 範例 |
|---|---|---|
| `line_msg.sh` | 傳訊息 | `line_msg.sh "Alice" "早安" 1` |
| `line_file.sh` | 傳檔案 | `line_file.sh "Alice" /tmp/a.png 1` |
| `line_call.sh` | 撥電話 | `line_call.sh "Alice" 5 1 voice` |
| `line_read.sh` | 讀訊息(截圖) | `line_read.sh "Alice" 1` |
| `line_list_chats.sh` | 列出最近聊天(截圖) | `line_list_chats.sh` |

共用模組:`wa_helpers.sh` / `line_helpers.sh`(座標、電話簿、共用函式)、`panel_select.scpt`(AX 選檔)、`wa_pick.scpt`(AX 選聊天)、`wa_read.scpt` / `wa_chats.scpt`(AX 讀取)。

完整自我測試:

```bash
# GUI 測試約需 70–85 秒,比一般 agent 指令逾時長,所以背景跑並讀結果檔。
nohup ./selftest.sh > /tmp/selftest_result.txt 2>&1 &
cat /tmp/selftest_result.txt   # 約 80 秒後
```

### 搭配 hermes 排程

```bash
hermes cron create '1m'        --no-agent --script my_send.sh --repeat 1   # 1 分鐘後
hermes cron create '0 9 * * *' --no-agent --script my_send.sh             # 每天 09:00
```

`--no-agent` 直接定時跑腳本(確定性、不經 LLM)。盲排只建議用 WhatsApp 的 URL scheme;LINE 與搜尋流程有打錯人風險,需視覺確認。

---

## 校準

座標是針對特定螢幕校準的,換機器幾乎一定要重抓 —— 不需改原始碼:

```bash
./calibrate.sh            # 兩個 App
./calibrate.sh whatsapp   # 只校準一個
```

它逐項提示你把滑鼠移到目標上按 Enter,用 `cliclick p` 讀座標,寫入 `messaging_coords.local.sh`(git-ignored),helpers 會自動載入。刪掉該檔即還原預設。

每個座標都是 `${VAR:-預設值}`,沒覆寫時行為不變;也可 `export WA_INPUT_X=860` 覆寫單一座標。

另外:把 `wa_helpers.sh` 的 `wa_curated_phone()` 換成你自己的聯絡人,且不要放自己的號碼(URL scheme 會開到自聊天)。

---

## 架構

```
hermes agent / 你
   │  ./wa_msg.sh "名字" "訊息"
   ▼
Wrapper 腳本 (wa_*.sh / line_*.sh)            流程編排 + 截圖驗證
   │  source / 呼叫
   ▼
Helpers (wa_helpers / line_helpers)  +  panel_select.scpt / wa_pick.scpt
   │  座標 (${VAR:-預設})、電話簿、AX 選取器
   ▼
cliclick(像素點擊) · AppleScript/System Events(AX、按鍵) · URL scheme(WhatsApp)
   ▼
LINE / WhatsApp 桌面 App
```

可靠度由高到低:WhatsApp URL scheme → AX 文字輸入/選檔/選聊天 → 像素座標(按鈕、LINE 選聊天;需校準 + 截圖確認)。

完整細節(AX 樹怪癖、各 App 開檔面板行為、防打錯人鐵律)見 [`SKILL.md`](SKILL.md)。

---

## Roadmap

已完成:

- [x] 傳訊息 / 傳檔 / 通話(WhatsApp + LINE)
- [x] 防送錯檔的檔案選取(AX 依檔名)
- [x] 依名字選對聯絡人(WhatsApp,AX)
- [x] 讀訊息與列出聊天(WhatsApp 文字 / LINE 截圖)
- [x] 回覆指定訊息(WhatsApp)
- [x] 動作後關聊天室(Esc,避免殘留已讀)
- [x] 座標校準(`calibrate.sh`)
- [x] `hermes cron` 排程(相對與絕對時間)

規劃中:

- [ ] 表情回應
- [ ] 首次/出錯自動初始化 + doctor:量測螢幕/縮放、自動 pin 視窗、盡量用 AX 推導座標、檢查 `cliclick`/Accessibility/App 是否開著。把手動 `calibrate.sh` 升級成「裝好即用,壞了自我診斷」。
- [ ] `tg_msg.sh` —— 包 `hermes send` 的薄 Telegram wrapper,提供一致的 `tg_msg.sh "聊天" "訊息"` 介面
- [ ] 用 MTProto(Telethon + API 憑證)DM 任意 Telegram 聯絡人。注意:送到已知對話用 `hermes send -t telegram:<chat_id> "..."` 已可(重用已設定的 bot),收訊由 hermes gateway 處理 —— Telegram 有官方 API,不需 UI 自動化。
- [ ] 未讀數 / 只讀不標已讀(可行性待研究)
- [ ] LINE 用 AX 選聊天(目前受阻:LINE 列為 `AXUnknown`)
- [ ] iMessage 整合(串既有 `imessage` skill)
- [ ] 視窗幾何自適應(讀實際 frame,減少校準)
- [ ] 深度歷史搜尋(UI 只看得到目前畫面)

歡迎 issue / PR。

---

## 注意事項

- `keystroke` 會過輸入法產生全形字、破壞路徑/訊息。一律用 `pbcopy + Cmd+V` 或 AX `set value`。
- 傳檔案用 `panel_select.scpt`(AX 依精確檔名)。不要用 Cmd+Shift+G 打路徑 —— 面板可能停在舊資料夾、靜默送錯檔。
- 所有座標以 pin 好的視窗 frame 為準;換環境先重新校準。
- 不要只信 exit 0 —— 用 `MEDIA:` 截圖確認訊息/通話/檔案真的送出,且送對人。

---

## 授權

MIT
