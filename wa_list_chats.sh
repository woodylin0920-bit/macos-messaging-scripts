#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# wa_list_chats.sh [count]
# List the most recent WhatsApp chats (names) as TEXT — read from the
# Accessibility tree, no vision needed. Useful for an agent to see "who's here"
# before deciding what to do.
#   wa_list_chats.sh        # top 15
#   wa_list_chats.sh 25

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wa_helpers.sh"

COUNT="${1:-15}"
wa_activate
wa_escape   # make sure we're on the chat list, not a search/chat
sleep 0.3
osascript "$SCRIPT_DIR/wa_chats.scpt" "$COUNT"
