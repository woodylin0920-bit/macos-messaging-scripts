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

## 目標 (Goals)

讓 hermes agent 在 macOS 上把 LINE / WhatsApp 當「另一支手機的助理」來操作,核心三原則:

- **精準** — 優先用 Accessibility(認元件 / 檔名 / 聯絡人名 / 鍵盤選單);**截圖只當最後手段**(LINE 內容 AX 讀不到才用)。防打錯人、防送錯檔。
- **速度 / 即時** — WhatsApp 讀取走 **AX 純文字**(快、便宜);避免冗餘截圖。
- **hermes agent 適配** — 腳本確定性、輸出乾淨可解析、能被 agent 一次跑完、可 `hermes cron` 排程、隨插即用(不申請 API、用已登入的桌面 App)。

## 測試目標 (Acceptance)

| # | 驗收項 | 狀態 |
|---|---|:---:|
| T1 | 六項基本功能:WA/LINE × 訊息/檔案/通話 | ✅ |
| T2 | 讀訊息(WA 純文字 / LINE 截圖)+ 列出最近聊天 | ✅ |
| T3 | 回覆指定訊息(WA:AX 定位 + 鍵盤選單) | ✅ |
| T4 | 防呆:不送錯檔(AX 檔名)、不打錯人(AX 名字/撞名退回)、不卡已讀(Esc) | ✅ |
| T5 | hermes agent 端到端(讀聊天 + 回答問題 / 執行腳本) | ✅ |
| T6 | 排程定時執行(相對時間 + 指定時間點) | ✅ |
| T7 | 從 Telegram 下一個指令 → agent 一次跑完全部並回報 | ✅ 11/11(背景跑 `selftest.sh`)|

> **一鍵自我測試**:`selftest.sh` 跑完整 WA+LINE 矩陣(11 項)並印 PASS/FAIL。
> 因 GUI 測試 >60s,從 agent(如 Telegram)觸發時用背景跑:
> ```bash
> nohup ~/.hermes/scripts/selftest.sh > /tmp/selftest_result.txt 2>&1 &   # 啟動
> cat /tmp/selftest_result.txt                                            # ~80s 後讀結果
> ```

---

## 功能矩陣

圖例:✅ 已完成 · 🔜 開發中/下一步 · ⚠️ 受限(可做但不穩/需視覺) · ❌ UI 做不到

| 功能 | WhatsApp | LINE | 說明 |
|---|:---:|:---:|---|
| 傳訊息 | ✅ | ✅ | CJK 安全(`pbcopy` + AX `set value`)|
| 傳檔案 | ✅ | ✅ | AX 依**檔名**精準選取 → **結構上不會送錯檔** |
| 語音 / 視訊通話 | ✅ | ✅ | 撥通 + 可設定 N 秒後自動掛斷 |
| 讀取訊息 | ✅ **AX 純文字** | ✅ 截圖+視覺 | WhatsApp 泡泡在 AX 樹可讀(含已讀狀態);LINE 為 `AXUnknown` 只能截圖 |
| 列出最近聊天 | ✅ **AX 純文字** | ✅ 截圖 | 讓 agent 先看「有誰、誰未讀」再行動 |
| 找對聯絡人 | ✅ AX 依名字 | ⚠️ 視覺確認 | WhatsApp 列是 AXButton;LINE 列 `AXUnknown` → 須截圖確認 |
| 開聊天室 | URL scheme(已知號碼最穩) | 搜尋(無 URL scheme) | |
| 群組送訊息 | ✅ | ✅ | 群組=有名字的 chat,沿用「依名字選」路徑 |
| 關聊天室(防卡已讀) | ✅ Esc | ✅ Esc | 動作後關閉,避免一直標 **已讀** |
| 排程定時執行 | ✅ `hermes cron` | ⚠️ | 盲排只建議 WhatsApp(URL scheme);LINE 須人工/視覺確認 |
| 回覆指定訊息 | ✅ | ⚠️ 較難 | WhatsApp:AX 依文字定位泡泡 → 右鍵 → **鍵盤** ↓+Enter 選「回覆」(不靠截圖)|
| 表情回應 react | 🔜 | ⚠️ | hover 觸發,靠座標 |
| 搜尋歷史訊息 | ❌ | ❌ | AX 只讀目前可見;深度歷史需另一套(見 Roadmap)|

**底層通用能力**
- 📐 **座標可校準化**:座標 `${VAR:-預設}`,可被環境變數 / `messaging_coords.local.sh` 覆寫;`calibrate.sh` 互動校準,換機器免改碼。
- 📸 **永不盲信 exit 0**:每個動作輸出 before/after 截圖路徑(`MEDIA:`),動作後截圖確認。
- 🧩 **AX 優先、座標為輔**:能用 Accessibility 認元件/檔名/名字的就用 AX(穩),其餘才用像素座標。

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
| `wa_read.sh` | 讀訊息(純文字) | `wa_read.sh "Alice" 12` |
| `wa_list_chats.sh` | 列出最近聊天 | `wa_list_chats.sh 15` |
| `wa_reply.sh` | 回覆指定訊息 | `wa_reply.sh "Alice" "要回覆的訊息片段" "回覆內容"` |

### LINE
| 腳本 | 功能 | 範例 |
|---|---|---|
| `line_msg.sh` | 傳訊息 | `line_msg.sh "Alice" "早安" 1` |
| `line_file.sh` | 傳檔案 | `line_file.sh "Alice" /tmp/a.png 1` |
| `line_call.sh` | 打電話 | `line_call.sh "Alice" 5 1 voice` |
| `line_read.sh` | 讀訊息(截圖→視覺) | `line_read.sh "Alice" 1` |
| `line_list_chats.sh` | 列出最近聊天(截圖) | `line_list_chats.sh` |

共用模組:`wa_helpers.sh` / `line_helpers.sh`(座標、電話簿、共用函式)、`panel_select.scpt`(AX 選檔)、`wa_pick.scpt`(AX 選人)、`wa_read.scpt` / `wa_chats.scpt`(AX 讀取)。

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

## Roadmap

**已完成**
- [x] 傳訊息 / 傳檔 / 通話(WhatsApp + LINE)
- [x] AX 防送錯檔的檔案選取
- [x] AX 依名字選對聯絡人(WhatsApp)
- [x] 讀取訊息、列出最近聊天(WhatsApp 純文字 / LINE 截圖)
- [x] Esc 關聊天室(防卡已讀)
- [x] 座標校準化 + `calibrate.sh`
- [x] `hermes cron` 定時執行(相對 + 指定時間)

**開發中 / 下一步**
- [ ] **回覆指定訊息**(WhatsApp 先做:AX 定位泡泡 → 右鍵「回覆」)
- [ ] **表情回應 react**
- [ ] **🩺 首次/出錯自動初始化(auto-init + doctor)** ← 規劃中
  - 第一次使用或偵測到錯誤時,自動跑一遍:量測螢幕解析度 / 縮放、自動 pin 視窗、盡量用 AX 推導座標、檢查 `cliclick` 與 Accessibility 權限、確認 App 已開並可 pin。
  - 等於把現在「手動 `calibrate.sh`」升級成「**裝好即用、壞了自動健檢**」,降低一般用戶門檻。

**待開發 / 未來**
- **Telegram** — 不走 UI 自動化(Telegram 有官方 API,比螢幕自動化穩)。
  - [x] **送訊息/檔案**:已可用 `hermes send -t telegram:<chat_id> "..."`(文字)/ `"MEDIA:<path>"`(檔案),重用已設定的 bot token(如 `@woody_dodo_bot`),無需 LLM。設 `hermes config set TELEGRAM_HOME_CHANNEL <id>` 後可省略 chat_id。
  - [x] **收指令/通知**:由 hermes gateway + bot 處理(就是你下指令的管道)。
  - [ ] **DM 任意聯絡人**(非 bot 已知的對話):需 MTProto 使用者 API(Telethon + API 憑證)—— 唯一還沒做的部分。
- [ ] **未讀數 / 只讀不標已讀**(研究是否可行)
- [ ] **LINE 選人改 AX**(目前列為 `AXUnknown`,等可讀路徑)
- [ ] **iMessage** 整合(串既有 `imessage` skill)
- [ ] **視窗幾何自適應**(自動讀實際 frame,減少校準)
- [ ] **深度歷史搜尋**(UI 只能讀目前可見;若真要跨大量歷史,才考慮非 UI 方案——但會犧牲隨插即用)

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
