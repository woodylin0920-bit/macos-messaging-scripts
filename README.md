# macOS Messaging Automation Scripts

> **LINE + WhatsApp 桌面版自動化** — 一個給 [Nous Research `hermes-agent`](https://github.com/nousresearch/hermes-agent) 用的 skill,也可當獨立 CLI 腳本直接跑。

用 **AppleScript + System Events + Accessibility (AX) + `cliclick`** 驅動 macOS 上的 LINE / WhatsApp 桌面 App:傳訊息、傳檔案、打語音/視訊電話,並可搭配 hermes 的排程器定時執行。

平台:**macOS only**。系統 `/bin/bash` 3.2 相容。

---

## 這是什麼 / 給誰用

- **作為 hermes skill**:`SKILL.md` 帶完整的 AX 樹怪癖、防打錯人規則與腳本說明,放進 `~/.hermes/skills/` 後,hermes agent 可直接「讀 skill → 呼叫腳本 → 操作 App」。已實測 hermes agent 能端到端執行(見下方測試結果)。
- **作為獨立腳本**:7 個 wrapper 腳本可直接在終端機跑,例如 `./wa_msg.sh "Alice" "嗨"`。

> ⚠️ **本質是座標 + AX 的螢幕自動化,不是官方 API。** 換螢幕/解析度/介面語言/App 版本,座標需重新校準(見 [移植 / 校準](#移植--校準))。文字輸入與檔案/聯絡人選取已盡量改用 AX(認元件/名字),比寫死座標穩。

---

## 功能

| App | 傳訊息 | 傳檔案 | 語音/視訊通話 | 開聊天室方式 |
|---|:---:|:---:|:---:|---|
| **WhatsApp** | ✅ | ✅ | ✅ | URL scheme(已知號碼,最穩)→ 否則 AX 依名字選人 |
| **LINE** | ✅ | ✅ | ✅ | 搜尋 + 截圖視覺確認(無 URL scheme) |

**通用能力**
- 🎯 **AX 選檔(防送錯檔)**:用檔名精準選取,找不到就中止,結構上不會送錯檔。
- 🎯 **AX 選人(WhatsApp)**:聊天列是 AXButton,依名字精準點擊,免座標、避免打錯人;撞名則退回視覺確認。
- 📐 **座標可校準化**:所有座標 `${VAR:-預設}`,可被環境變數或 `messaging_coords.local.sh` 覆寫;附互動校準腳本 `calibrate.sh`,換機器不用改原始碼。
- ⏰ **可排程**:搭配 `hermes cron` 定時執行(相對時間如 `1m` / 指定時間如 `40 16 * * *`),實測兩種都能觸發。
- 🈶 **CJK 安全輸入**:用 `pbcopy + AX set value` 塞文字,避開輸入法全型字問題。
- 📸 **永不盲信 exit 0**:每個動作輸出 before/after 截圖路徑,動作後用截圖確認。

---

## 測試結果(2026-06-16,實機驗證)

| 測試 | 結果 |
|---|:---:|
| WhatsApp 傳訊息 / 傳檔 / 通話 | ✅ ✅ ✅ |
| LINE 傳訊息 / 傳檔 / 通話 | ✅ ✅ ✅ |
| AX 選檔送出正確檔(不送錯檔) | ✅ |
| AX 依名字選對聯絡人 | ✅ |
| **hermes agent 端到端執行**(讀 skill → 跑腳本 → 送出) | ✅ |
| **排程觸發**:相對時間 `1m` + 指定時間 `40 16 * * *` | ✅ ✅ |

六項功能 + agent 執行 + 排程,皆逐項以截圖確認送達。

---

## 需求

1. **macOS**,系統 `/bin/bash` 3.2(腳本已避開 `declare -A` 與 `$()` 內 heredoc)。
2. **cliclick** — `brew install cliclick`。
3. **Accessibility 權限** — 系統設定 → 隱私權與安全性 → 輔助使用 → 加入你的終端機 /（跑 hermes 的程式）。沒給會出現 `osascript 不允許輔助取用 (-25211)`。
4. **LINE / WhatsApp 桌面版**已登入並開著。

---

## 安裝

**當 hermes skill**
```bash
# 放進 hermes 的 skills 目錄(路徑依你的 hermes 安裝)
cp -R macos-messaging-scripts ~/.hermes/skills/apple/macos-messaging
# 腳本就位後校準座標(見下)
```

**當獨立腳本**
```bash
git clone https://github.com/woodylin0920-bit/macos-messaging-scripts
cd macos-messaging-scripts && chmod +x *.sh
./calibrate.sh        # 校準座標到你的螢幕
```

---

## 用法

### WhatsApp
| 腳本 | 功能 | 範例 |
|---|---|---|
| `wa_msg.sh` | 傳訊息 | `wa_msg.sh "Alice" "嗨"` |
| `wa_file.sh` | 傳檔案 | `wa_file.sh "Alice" /tmp/a.pdf "" "說明文字"` |
| `wa_call.sh` | 打電話 | `wa_call.sh "Alice" 5 voice`（撥通 5 秒後掛斷）|

### LINE
| 腳本 | 功能 | 範例 |
|---|---|---|
| `line_msg.sh` | 傳訊息 | `line_msg.sh "Alice" "早安" 1` |
| `line_file.sh` | 傳檔案 | `line_file.sh "Alice" /tmp/a.png 1` |
| `line_call.sh` | 打電話 | `line_call.sh "Alice" 5 1 voice` |

共用模組:`wa_helpers.sh` / `line_helpers.sh`(座標、電話簿、所有共用函式)、`panel_select.scpt`(AX 選檔)、`wa_pick.scpt`(AX 選人)。

### 搭配 hermes 排程(定時送)
```bash
# 相對時間:1 分鐘後送一次
hermes cron create '1m' --no-agent --script my_send.sh --repeat 1
# 指定時間:每天 09:00
hermes cron create '0 9 * * *' --no-agent --script my_send.sh
```
> `--no-agent` = 不經 LLM、直接定時跑腳本(確定性、cron-safe)。盲排只建議用 WhatsApp 已知號碼(URL scheme),LINE / 搜尋有打錯人風險,須人工/視覺確認。

---

## 移植 / 校準（換機器一定要做）

座標是針對特定螢幕校準的,換機器幾乎一定要重抓 —— 但**不需要改原始碼**:

```bash
./calibrate.sh            # LINE + WhatsApp 都校準
./calibrate.sh whatsapp   # 只校準 WhatsApp
```

它逐項提示「把滑鼠移到某按鈕按 Enter」,用 `cliclick p` 讀座標,產生 `messaging_coords.local.sh`(已 git-ignore)。helpers 會自動載入它覆寫預設。**刪掉該檔即還原預設。**

> 原理:每個座標寫成 `${VAR:-預設值}`。沒覆寫時完全等於原值(行為不變)。也可 `export WA_INPUT_X=860` 臨時覆寫單一座標。

其他要點:把 `wa_helpers.sh` 的 `wa_curated_phone()` 換成你自己的聯絡人;**不要把自己的號碼放進去**(URL scheme 會開到自聊天)。介面語言非繁中時,腳本內寫死的字串(`檔案`、`確定要與X進行通話?` 等)需跟著改。

---

## 架構

```
hermes agent / 你
   │  ./wa_msg.sh "名字" "訊息"
   ▼
Wrapper 腳本 (wa_*.sh / line_*.sh)   ← 流程編排 + 截圖驗證
   │ source / 呼叫
   ▼
Helpers (wa_helpers / line_helpers)  +  panel_select.scpt / wa_pick.scpt
   │  座標(${VAR:-預設})、電話簿、AX 選檔/選人
   ▼
cliclick(像素點擊)  ·  AppleScript/System Events(AX 讀寫、按鍵)  ·  URL scheme(WhatsApp)
   ▼
LINE / WhatsApp 桌面 App
```

**可靠度光譜**(穩 → 脆):WhatsApp URL scheme ▸ AX 文字輸入/選檔/選人 ▸ 像素座標(按鈕、LINE 找聊天,需校準 + 截圖確認)。

完整細節(AX 樹怪癖、各 App 開檔面板差異、防打錯人鐵律)見 [`SKILL.md`](SKILL.md)。

---

## Roadmap / 待新增

- [ ] **Telegram** 傳訊息 / 傳檔(可走 hermes gateway 的 `--deliver telegram`,或桌面版自動化)
- [ ] **WhatsApp / LINE 讀取訊息**(讀最近對話、未讀)
- [ ] **群組** 支援(指定群組送、@提及)
- [ ] **訊息回覆 / 表情回應**(reply、reaction)
- [ ] **LINE 選人改 AX**(目前 LINE 列在 AX 為 `AXUnknown`,只能視覺確認;待 LINE 改版或找到可讀路徑)
- [ ] **iMessage** 整合(與既有 `imessage` skill 串接)
- [ ] **更穩的視窗幾何自適應**(自動讀實際視窗 frame,減少校準需求)

歡迎 issue / PR。

---

## 關鍵教訓

- `keystroke` 過輸入法 → 全型字 → 路徑/訊息壞掉。一律 `pbcopy + Cmd+V` 或 AX `set value`。
- 傳檔案用 `panel_select.scpt`(AX 依檔名精準選),**不要**用 Cmd+Shift+G 打路徑(面板可能停在舊資料夾 → 靜默送錯檔)。
- 所有座標以 pin 好的視窗 frame 為準;換環境先 `calibrate.sh`。
- **永遠不要只信 exit 0** —— 動作後用 `MEDIA:` 截圖確認真的送出 / 撥通 / 送對人。

---

## 授權
MIT
