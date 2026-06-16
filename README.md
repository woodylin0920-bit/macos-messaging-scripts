# macOS Messaging Automation Scripts

LINE + WhatsApp 桌面版自動化腳本（AppleScript + System Events + cliclick）。

> ⚠️ **這是座標式螢幕自動化,不是 API。** 所有點擊座標都是針對「特定螢幕 +
> 特定視窗大小 + 繁體中文介面」校準的。換一台機器、換解析度、換介面語言、
> 或 LINE/WhatsApp 改版,**座標就會跑掉,你必須重新校準**（見下方「移植 / 校準」）。

## 需求

1. **macOS**，系統 `/bin/bash` 3.2（腳本已避開 `declare -A` 與 `$()` 內 heredoc）
2. **cliclick** — `brew install cliclick`
3. **Accessibility 權限** — 系統設定 → 隱私權與安全性 → 輔助使用 → 加入你的終端機
   （沒給會出現 `osascript 不允許輔助取用 (-25211)`）
4. **LINE / WhatsApp 桌面版**已登入並開著

## 腳本清單

### WhatsApp
| 腳本 | 功能 | 用法 |
|---|---|---|
| `wa_msg.sh` | 傳訊息 | `wa_msg.sh <聯絡人> <訊息>` |
| `wa_file.sh` | 傳檔案 | `wa_file.sh <聯絡人> <檔案路徑> [result_idx] [caption]` |
| `wa_call.sh` | 打電話 | `wa_call.sh <聯絡人> [掛斷秒數] [voice\|video]` |
| `wa_helpers.sh` | 共用模組 | 座標、電話簿、所有共用函數 |

### LINE
| 腳本 | 功能 | 用法 |
|---|---|---|
| `line_msg.sh` | 傳訊息 | `line_msg.sh <聯絡人> <訊息> [result_idx]` |
| `line_file.sh` | 傳檔案 | `line_file.sh <聯絡人> <檔案路徑> [result_idx]` |
| `line_call.sh` | 打電話 | `line_call.sh <聯絡人> [掛斷秒數] [result_idx]` |
| `line_helpers.sh` | 共用模組 | 座標、所有共用函數 |

`send_msg.sh` 是最簡單的「對目前聚焦的輸入框送一則訊息」範例。

## 邏輯
- **WhatsApp**：URL scheme 優先（有電話號碼直開聊天室），沒號碼才搜尋
- **LINE**：只能搜尋（沒 URL scheme），截圖確認後再動作

## 移植 / 校準（換機器一定要做）

座標常數都集中在 `wa_helpers.sh` / `line_helpers.sh` 最上方。重抓步驟：

1. **先 pin 視窗**到腳本假設的 frame（WhatsApp `{0,25} 1440×875`、LINE `{0,30} 1440×794`）。
   你也可以改腳本裡的 frame 成自己慣用的大小,但改了就要重抓下面所有座標。
2. **讀游標座標**：終端機跑 `cliclick p`，把滑鼠移到目標按鈕（輸入框、電話 icon、
   選單項目…）上,記下印出的 `x,y`，回填到對應常數。
3. **介面語言**：腳本內寫死了繁中字串（`檔案`、`確定要與X進行通話?`、
   `你的對話和通話均受隱私保護` 隱私 popup）。介面非繁中的話,選單位置與這些
   文字都要跟著改。
4. **電話簿**：把 `wa_helpers.sh` 的 `wa_curated_phone()` 換成你自己的聯絡人
   （目前是 `alice` / `bob smith` 範例）。**不要把自己的號碼放進去**,否則 URL
   scheme 會開到自聊天。
5. 改寫腳本後記得 `chmod +x *.sh`（覆寫常常會掉執行權限）。

## 關鍵教訓
- `keystroke` 過輸入法 → 全型字 → 路徑壞掉。一律用 `pbcopy + Cmd+V`
- Finder panel 的 Cmd+Shift+G 要先 click panel 拿 focus
- 所有座標以 pin 好的視窗 frame 為準
- **永遠不要只信 exit 0**：腳本會輸出 before/after 截圖路徑（`MEDIA:`），
  動作後用截圖確認真的送出 / 撥通 / 送對人

完整細節（AX tree 怪癖、各 app open panel 差異、防打錯人規則）見 `SKILL.md`。

## 授權
MIT
