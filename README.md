# macOS Messaging Automation Scripts

![Platform](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)
![Bash](https://img.shields.io/badge/bash-3.2%2B-4EAA25?logo=gnubash&logoColor=white)
![hermes-agent](https://img.shields.io/badge/hermes--agent-skill-7B68EE)

**English** · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md)

An **AI-agent skill** for
[Nous Research `hermes-agent`](https://github.com/nousresearch/hermes-agent)
(also runnable as standalone shell scripts) that drives the **LINE** and
**WhatsApp** desktop apps on macOS — send messages, send files, place
voice/video calls, read and list chats, and reply to a specific message.

Driven by AppleScript + System Events + Accessibility (AX) + [`cliclick`](https://github.com/BlueM/cliclick).
No third-party API keys, no QR linking — it controls the desktop apps you are
already logged into.

> **macOS only.** Compatible with the system `/bin/bash` 3.2.

---

## Overview

There is no good public API for personal LINE/WhatsApp messaging, so this drives
the desktop apps directly. The design favors the Accessibility tree (matching
elements, filenames, contact names, keyboard menus) and falls back to pixel
coordinates only where AX is unavailable. Screenshots are a last resort, used
only for LINE content that AX cannot read.

Two ways to use it:

- **As a hermes skill** — drop it in `~/.hermes/skills/`. `SKILL.md` documents the
  AX quirks and the wrong-person/wrong-file safety rules; the agent reads the
  skill, calls the scripts, and operates the apps.
- **As standalone scripts** — run any wrapper directly, e.g. `./wa_msg.sh "Alice" "hi"`.

**Caveat:** this is coordinate + AX screen automation, not an official API. A
different screen, resolution, UI language, or app version may require
recalibrating coordinates (see [Calibration](#calibration)).

---

## Features

`✓` working · `partial` limited / needs vision · `planned` not yet · `—` n/a

| Capability | WhatsApp | LINE | Notes |
|---|:---:|:---:|---|
| Send message | ✓ | ✓ | CJK-safe (`pbcopy` + AX `set value`) |
| Send file | ✓ | ✓ | AX selects by exact filename — cannot send the wrong file |
| Voice / video call | ✓ | ✓ | Places the call, optional auto-hangup after N seconds |
| Read messages | ✓ text | partial | WhatsApp bubbles are AX-readable as text; LINE content is `AXUnknown`, so it returns a screenshot for a vision model |
| List recent chats | ✓ text | partial | Lets the agent see who's around before acting |
| Find the right chat | ✓ by name | partial | WhatsApp rows are AX buttons; LINE rows are `AXUnknown` (screenshot-confirmed) |
| Group send | ✓ | ✓ | A group is just a named chat |
| Reply to a message | ✓ | planned | WhatsApp: AX-locate the bubble by text, right-click, then keyboard ↓+Enter to pick Reply (no screenshot) |
| Close chat after action | ✓ | ✓ | Esc, so the app isn't left marking incoming messages read |
| Scheduling | ✓ | partial | Via `hermes cron`; blind scheduling is recommended for WhatsApp only |
| React with emoji | planned | planned | |
| Search message history | — | — | AX only sees what's on screen |

Cross-cutting:

- **Calibratable coordinates.** Every coordinate is `${VAR:-default}` and can be
  overridden by an env var or a git-ignored `messaging_coords.local.sh`.
  `calibrate.sh` captures them interactively — no source edits needed.
- **Never trusts exit 0.** Every action prints a before/after screenshot path
  (`MEDIA:`) so the result can be confirmed.
- **AX first, pixels second.** Whatever AX can identify (element, filename, name,
  keyboard menu) goes through AX; pixel coordinates are the fallback.

Verified end-to-end on real LINE/WhatsApp on 2026-06-16: all of the above plus a
hermes agent run and `hermes cron` scheduling (relative and absolute time).
`selftest.sh` runs the full 11-item matrix and reports pass/fail (11/11).

---

## Requirements

1. macOS with the system `/bin/bash` 3.2 (scripts avoid `declare -A` and
   heredocs inside `$()`).
2. `cliclick` — `brew install cliclick`.
3. Accessibility permission — System Settings → Privacy & Security →
   Accessibility → add your terminal (or whatever runs hermes). Without it:
   `osascript 不允許輔助取用 (-25211)`.
4. LINE / WhatsApp desktop apps installed, logged in, and running.

> The UI strings the scripts click are Traditional Chinese (`檔案`,
> `確定要與X進行通話?`, etc.). On a non-Chinese UI, those strings need adjusting.

---

## Install

As a hermes skill:

```bash
cp -R macos-messaging-scripts ~/.hermes/skills/apple/macos-messaging
```

Standalone:

```bash
git clone https://github.com/woodylin0920-bit/macos-messaging-scripts
cd macos-messaging-scripts && chmod +x *.sh
./calibrate.sh   # calibrate coordinates for your screen
```

---

## Usage

WhatsApp:

| Script | Purpose | Example |
|---|---|---|
| `wa_msg.sh` | Send a message | `wa_msg.sh "Alice" "hi"` |
| `wa_file.sh` | Send a file | `wa_file.sh "Alice" /tmp/a.pdf "" "caption"` |
| `wa_call.sh` | Place a call | `wa_call.sh "Alice" 5 voice` (hang up after 5s) |
| `wa_read.sh` | Read messages (text) | `wa_read.sh "Alice" 12` |
| `wa_list_chats.sh` | List recent chats | `wa_list_chats.sh 15` |
| `wa_reply.sh` | Reply to a message | `wa_reply.sh "Alice" "text to match" "reply"` |

LINE:

| Script | Purpose | Example |
|---|---|---|
| `line_msg.sh` | Send a message | `line_msg.sh "Alice" "morning" 1` |
| `line_file.sh` | Send a file | `line_file.sh "Alice" /tmp/a.png 1` |
| `line_call.sh` | Place a call | `line_call.sh "Alice" 5 1 voice` |
| `line_read.sh` | Read messages (screenshot) | `line_read.sh "Alice" 1` |
| `line_list_chats.sh` | List recent chats (screenshot) | `line_list_chats.sh` |

Shared modules: `wa_helpers.sh` / `line_helpers.sh` (coordinates, phone book,
shared functions), `panel_select.scpt` (AX file picker), `wa_pick.scpt` (AX chat
picker), `wa_read.scpt` / `wa_chats.scpt` (AX readers).

Full self-test:

```bash
# The GUI suite takes ~70–85s, longer than a typical agent command timeout,
# so run it detached and read the result file.
nohup ./selftest.sh > /tmp/selftest_result.txt 2>&1 &
cat /tmp/selftest_result.txt   # ~80s later
```

### Scheduling with hermes

```bash
hermes cron create '1m'        --no-agent --script my_send.sh --repeat 1   # in 1 minute
hermes cron create '0 9 * * *' --no-agent --script my_send.sh             # daily at 09:00
```

`--no-agent` runs the script directly on schedule (deterministic, no LLM). Blind
scheduling is recommended for WhatsApp via the URL scheme only; LINE and search
flows carry wrong-person risk and need vision confirmation.

---

## Calibration

Coordinates are calibrated for a specific screen, so a new machine almost always
needs recalibration — without editing source:

```bash
./calibrate.sh            # both apps
./calibrate.sh whatsapp   # one app
```

It prompts you to hover each target and press Enter, reads the position with
`cliclick p`, and writes `messaging_coords.local.sh` (git-ignored), which the
helpers auto-load. Delete that file to restore defaults.

Each coordinate is `${VAR:-default}`, so with nothing overridden the behavior is
unchanged; you can also `export WA_INPUT_X=860` to override a single value.

Also: replace `wa_curated_phone()` in `wa_helpers.sh` with your own contacts, and
do not put your own number there (the URL scheme would open the self-chat).

---

## Architecture

```
hermes agent / you
   │  ./wa_msg.sh "name" "message"
   ▼
Wrapper scripts (wa_*.sh / line_*.sh)        flow + screenshot verification
   │  source / call
   ▼
Helpers (wa_helpers / line_helpers)  +  panel_select.scpt / wa_pick.scpt
   │  coordinates (${VAR:-default}), phone book, AX pickers
   ▼
cliclick (pixel clicks) · AppleScript/System Events (AX, keys) · URL scheme (WhatsApp)
   ▼
LINE / WhatsApp desktop apps
```

Reliability, most to least robust: WhatsApp URL scheme → AX text input / file
pick / chat pick → pixel coordinates (buttons, LINE chat selection; need
calibration + screenshot confirmation).

See [`SKILL.md`](SKILL.md) for the full details (AX tree quirks, per-app open
panel behavior, the anti-wrong-person rules).

---

## Roadmap

Done:

- [x] Send / file / call (WhatsApp + LINE)
- [x] Wrong-file-proof file selection (AX by filename)
- [x] Pick the right contact by name (WhatsApp, AX)
- [x] Read messages and list chats (WhatsApp text / LINE screenshot)
- [x] Reply to a specific message (WhatsApp)
- [x] Close chat after an action (Esc, avoids stale read receipts)
- [x] Coordinate calibration (`calibrate.sh`)
- [x] Scheduled runs via `hermes cron` (relative and absolute time)

Planned:

- [ ] Emoji reactions
- [ ] First-run auto-init + doctor: measure screen/scale, auto-pin the window,
      derive coordinates from AX where possible, check `cliclick` / Accessibility
      / apps-running. Turns manual `calibrate.sh` into "works out of the box, and
      self-diagnoses when something breaks."
- [ ] `tg_msg.sh` — thin Telegram wrapper around `hermes send` for a consistent
      `tg_msg.sh "chat" "message"` interface
- [ ] Telegram DM to arbitrary contacts via MTProto (Telethon + API credentials).
      Note: outbound to a known chat already works with
      `hermes send -t telegram:<chat_id> "..."` (reuses the configured bot), and
      inbound is handled by the hermes gateway — Telegram has a real API, so no UI
      automation is needed.
- [ ] Unread counts / read-without-marking-read (feasibility unclear)
- [ ] LINE chat picking via AX (blocked: LINE rows are `AXUnknown` today)
- [ ] **WeChat (微信)** desktop automation — same UI/AX approach as LINE/WhatsApp
      (no official personal-messaging API). Likely screenshot + vision like LINE;
      note WeChat is aggressive about anti-automation, so account-ban risk is higher
- [ ] iMessage integration (with the existing `imessage` skill)
- [ ] Window-geometry auto-fit (read the actual frame, reduce calibration)
- [ ] Deep history search (UI only sees what's on screen)

Issues and PRs welcome.

---

## Notes / gotchas

- `keystroke` goes through the input method and produces full-width characters
  that break paths/messages. Always use `pbcopy + Cmd+V` or AX `set value`.
- Send files with `panel_select.scpt` (AX, by exact filename). Do not type a
  path via Cmd+Shift+G — the panel can sit on a stale folder and silently send
  the wrong file.
- All coordinates assume the pinned window frame; recalibrate after changing
  environment.
- Never trust exit 0 alone — confirm with the `MEDIA:` screenshots that the
  message/call/file actually went through, and to the right person.

---

## Disclaimer

This project automates personal LINE/WhatsApp accounts through the desktop apps'
UI. It is provided for **personal, individual use**, as-is and without warranty.

- Automating a personal account may violate the **WhatsApp / LINE Terms of
  Service**; the typical consequence is account suspension. Use at your own risk.
- Do **not** use it for spam, bulk or unsolicited messaging, impersonation, or
  reading/collecting other people's messages without consent — beyond the ToS,
  those may breach anti-spam and privacy laws.
- For commercial or large-scale use, consult a lawyer and use the official APIs
  (WhatsApp Business Cloud API, LINE Messaging API) instead.

The authors are not responsible for how you use this software.

## License

MIT
