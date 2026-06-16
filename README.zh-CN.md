# macOS 即时通讯自动化脚本

![Platform](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)
![Bash](https://img.shields.io/badge/bash-3.2%2B-4EAA25?logo=gnubash&logoColor=white)
![hermes-agent](https://img.shields.io/badge/hermes--agent-skill-7B68EE)

[English](README.md) · [繁體中文](README.zh-TW.md) · **简体中文**

在 macOS 上自动化 **LINE** 与 **WhatsApp** 桌面版 —— 发消息、发文件、拨语音/视频电话、读取与列出会话、回复指定消息。设计为 [Nous Research `hermes-agent`](https://github.com/nousresearch/hermes-agent) 的 skill,也可作为独立 shell 脚本使用。

底层用 AppleScript + System Events + Accessibility (AX) + [`cliclick`](https://github.com/BlueM/cliclick) 驱动。无需第三方 API 密钥、不用扫码 —— 直接操作你已登录的桌面 App。

> **仅限 macOS。** 兼容系统 `/bin/bash` 3.2。

---

## 概述

个人 LINE/WhatsApp 消息没有好用的公开 API,所以本工具直接操作桌面 App。设计上优先使用 Accessibility 树(匹配控件、文件名、联系人名、键盘菜单),只有 AX 取不到时才回退到像素坐标。截图是最后手段,只用于 AX 读不到的 LINE 内容。

两种用法:

- **作为 hermes skill** —— 放进 `~/.hermes/skills/`。`SKILL.md` 记录了 AX 的坑与「防发错人/防发错文件」规则;agent 读 skill、调用脚本、操作 App。
- **作为独立脚本** —— 直接运行任一 wrapper,例如 `./wa_msg.sh "Alice" "你好"`。

**注意:** 这是坐标 + AX 的屏幕自动化,不是官方 API。换屏幕、分辨率、界面语言或 App 版本,可能需要重新校准坐标(见 [校准](#校准))。

---

## 功能

`✓` 可用 · `partial` 受限/需视觉 · `planned` 待实现 · `—` 不适用

| 功能 | WhatsApp | LINE | 说明 |
|---|:---:|:---:|---|
| 发消息 | ✓ | ✓ | CJK 安全(`pbcopy` + AX `set value`) |
| 发文件 | ✓ | ✓ | AX 按精确文件名选择,不会发错文件 |
| 语音/视频通话 | ✓ | ✓ | 拨出,可选 N 秒后自动挂断 |
| 读取消息 | ✓ 文本 | partial | WhatsApp 气泡 AX 可读成文本;LINE 内容为 `AXUnknown`,改为返回截图给视觉模型 |
| 列出最近会话 | ✓ 文本 | partial | 让 agent 先看有谁再行动 |
| 找到正确会话 | ✓ 按名字 | partial | WhatsApp 行是 AX button;LINE 行为 `AXUnknown`(需截图确认) |
| 群组发送 | ✓ | ✓ | 群组就是有名字的会话 |
| 回复指定消息 | ✓ | planned | WhatsApp:AX 按文本定位气泡 → 右键 → 键盘 ↓+Enter 选「回复」(不靠截图) |
| 操作后关闭会话 | ✓ | ✓ | Esc,避免 App 一直把新消息标记为已读 |
| 定时调度 | ✓ | partial | 通过 `hermes cron`;盲调度仅建议 WhatsApp |
| 表情回应 | planned | planned | |
| 搜索历史消息 | — | — | AX 只能看到当前屏幕 |

通用能力:

- **坐标可校准。** 每个坐标都是 `${VAR:-默认值}`,可由环境变量或被 git 忽略的 `messaging_coords.local.sh` 覆盖。`calibrate.sh` 交互式采集,无需改源码。
- **不只信 exit 0。** 每个动作都打印 before/after 截图路径(`MEDIA:`)供确认。
- **AX 优先、像素其次。** AX 能识别的(控件、文件名、名字、键盘菜单)就走 AX,其余才用像素坐标。

已于 2026-06-16 在真机 LINE/WhatsApp 端到端验证:以上全部,加上一次 hermes agent 运行与 `hermes cron` 调度(相对与绝对时间)。`selftest.sh` 跑完整 11 项矩阵并报告通过/失败(11/11)。

---

## 依赖

1. macOS,系统 `/bin/bash` 3.2(脚本已避开 `declare -A` 与 `$()` 内 heredoc)。
2. `cliclick` —— `brew install cliclick`。
3. Accessibility 权限 —— 系统设置 → 隐私与安全性 → 辅助功能 → 添加你的终端(或运行 hermes 的程序)。未授予会出现 `osascript 不允许辅助使用 (-25211)`。
4. LINE / WhatsApp 桌面版已安装、登录并运行。

> 脚本点击的界面字符串是繁体中文(`檔案`、`確定要與X進行通話?` 等)。界面非中文时这些字符串需调整。

---

## 安装

作为 hermes skill:

```bash
cp -R macos-messaging-scripts ~/.hermes/skills/apple/macos-messaging
```

独立使用:

```bash
git clone https://github.com/woodylin0920-bit/macos-messaging-scripts
cd macos-messaging-scripts && chmod +x *.sh
./calibrate.sh   # 校准坐标到你的屏幕
```

---

## 用法

WhatsApp:

| 脚本 | 功能 | 示例 |
|---|---|---|
| `wa_msg.sh` | 发消息 | `wa_msg.sh "Alice" "你好"` |
| `wa_file.sh` | 发文件 | `wa_file.sh "Alice" /tmp/a.pdf "" "说明文字"` |
| `wa_call.sh` | 拨电话 | `wa_call.sh "Alice" 5 voice`(5 秒后挂断) |
| `wa_read.sh` | 读消息(文本) | `wa_read.sh "Alice" 12` |
| `wa_list_chats.sh` | 列出最近会话 | `wa_list_chats.sh 15` |
| `wa_reply.sh` | 回复指定消息 | `wa_reply.sh "Alice" "要匹配的文本" "回复内容"` |

LINE:

| 脚本 | 功能 | 示例 |
|---|---|---|
| `line_msg.sh` | 发消息 | `line_msg.sh "Alice" "早安" 1` |
| `line_file.sh` | 发文件 | `line_file.sh "Alice" /tmp/a.png 1` |
| `line_call.sh` | 拨电话 | `line_call.sh "Alice" 5 1 voice` |
| `line_read.sh` | 读消息(截图) | `line_read.sh "Alice" 1` |
| `line_list_chats.sh` | 列出最近会话(截图) | `line_list_chats.sh` |

共用模块:`wa_helpers.sh` / `line_helpers.sh`(坐标、电话簿、共用函数)、`panel_select.scpt`(AX 选文件)、`wa_pick.scpt`(AX 选会话)、`wa_read.scpt` / `wa_chats.scpt`(AX 读取)。

完整自检:

```bash
# GUI 测试约需 70–85 秒,比一般 agent 命令超时长,所以后台运行并读结果文件。
nohup ./selftest.sh > /tmp/selftest_result.txt 2>&1 &
cat /tmp/selftest_result.txt   # 约 80 秒后
```

### 配合 hermes 调度

```bash
hermes cron create '1m'        --no-agent --script my_send.sh --repeat 1   # 1 分钟后
hermes cron create '0 9 * * *' --no-agent --script my_send.sh             # 每天 09:00
```

`--no-agent` 直接按时运行脚本(确定性、不经 LLM)。盲调度仅建议用 WhatsApp 的 URL scheme;LINE 与搜索流程有发错人风险,需视觉确认。

---

## 校准

坐标是针对特定屏幕校准的,换机器几乎一定要重抓 —— 无需改源码:

```bash
./calibrate.sh            # 两个 App
./calibrate.sh whatsapp   # 只校准一个
```

它逐项提示你把鼠标移到目标上按 Enter,用 `cliclick p` 读坐标,写入 `messaging_coords.local.sh`(git 忽略),helpers 会自动加载。删除该文件即恢复默认。

每个坐标都是 `${VAR:-默认值}`,未覆盖时行为不变;也可 `export WA_INPUT_X=860` 覆盖单个坐标。

另外:把 `wa_helpers.sh` 的 `wa_curated_phone()` 换成你自己的联系人,且不要放自己的号码(URL scheme 会打开自聊天)。

---

## 架构

```
hermes agent / 你
   │  ./wa_msg.sh "名字" "消息"
   ▼
Wrapper 脚本 (wa_*.sh / line_*.sh)            流程编排 + 截图验证
   │  source / 调用
   ▼
Helpers (wa_helpers / line_helpers)  +  panel_select.scpt / wa_pick.scpt
   │  坐标 (${VAR:-默认})、电话簿、AX 选择器
   ▼
cliclick(像素点击) · AppleScript/System Events(AX、按键) · URL scheme(WhatsApp)
   ▼
LINE / WhatsApp 桌面 App
```

可靠度由高到低:WhatsApp URL scheme → AX 文本输入/选文件/选会话 → 像素坐标(按钮、LINE 选会话;需校准 + 截图确认)。

完整细节(AX 树的坑、各 App 打开面板的行为、防发错人铁律)见 [`SKILL.md`](SKILL.md)。

---

## Roadmap

已完成:

- [x] 发消息 / 发文件 / 通话(WhatsApp + LINE)
- [x] 防发错文件的文件选择(AX 按文件名)
- [x] 按名字选对联系人(WhatsApp,AX)
- [x] 读消息与列出会话(WhatsApp 文本 / LINE 截图)
- [x] 回复指定消息(WhatsApp)
- [x] 操作后关闭会话(Esc,避免残留已读)
- [x] 坐标校准(`calibrate.sh`)
- [x] `hermes cron` 调度(相对与绝对时间)

规划中:

- [ ] 表情回应
- [ ] 首次/出错自动初始化 + doctor:测量屏幕/缩放、自动 pin 窗口、尽量用 AX 推导坐标、检查 `cliclick`/Accessibility/App 是否运行。把手动 `calibrate.sh` 升级成「开箱即用,出错自我诊断」。
- [ ] `tg_msg.sh` —— 包 `hermes send` 的轻量 Telegram wrapper,提供一致的 `tg_msg.sh "会话" "消息"` 接口
- [ ] 用 MTProto(Telethon + API 凭证)私聊任意 Telegram 联系人。注意:发送到已知会话用 `hermes send -t telegram:<chat_id> "..."` 已可用(复用已配置的 bot),收信由 hermes gateway 处理 —— Telegram 有官方 API,无需 UI 自动化。
- [ ] 未读数 / 只读不标已读(可行性待研究)
- [ ] LINE 用 AX 选会话(目前受阻:LINE 行为 `AXUnknown`)
- [ ] iMessage 集成(对接现有 `imessage` skill)
- [ ] 窗口几何自适应(读实际 frame,减少校准)
- [ ] 深度历史搜索(UI 只能看到当前屏幕)

欢迎 issue / PR。

---

## 注意事项

- `keystroke` 会经过输入法产生全角字符、破坏路径/消息。一律用 `pbcopy + Cmd+V` 或 AX `set value`。
- 发文件用 `panel_select.scpt`(AX 按精确文件名)。不要用 Cmd+Shift+G 输入路径 —— 面板可能停在旧文件夹、静默发错文件。
- 所有坐标以 pin 好的窗口 frame 为准;换环境先重新校准。
- 不要只信 exit 0 —— 用 `MEDIA:` 截图确认消息/通话/文件真的发出,且发对人。

---

## 许可证

MIT
