#!/usr/bin/env bash
# OakMega Developer plugin — 版本守門
#
# 由 commands/web-tool-component.md 與兩份 SKILL.md 在開頭直接呼叫
# （不走 hook —— 桌面版的 plugin hook 沒有被觸發，改用這條確定會跑的路）。
#
# 每次都做：
#   1. 抓 GitHub 上的 plugin.json，比對 version（一個幾百 bytes 的 HTTP GET）
#   2. 遠端比較新 → 下載 tarball，把新檔案換進 plugin 快取目錄
#   3. 提示使用者重新啟動 Claude Code
#
# 沒有快取、沒有狀態檔：每次都直接問一次 GitHub，答案永遠是當下的事實。
# 相依：curl（或 wget）+ tar。兩者 macOS／Linux／Git for Windows 都內建。
# 都沒有的話退回用 git；連 git 都沒有就靜默跳過。
# 任何一步失敗都靜默結束（exit 0），絕不擋住 session。

set -uo pipefail

SLUG="oakmega/OakMega-Developer-Plugin"
PLUGIN_SUBDIR="oakmega-developer"

RAW_URL="https://raw.githubusercontent.com/$SLUG/HEAD/$PLUGIN_SUBDIR/.claude-plugin/plugin.json"
TAR_URL="https://codeload.github.com/$SLUG/tar.gz/HEAD"
GIT_URL="https://github.com/$SLUG.git"

# 由 skill／指令的 markdown 直接呼叫。CLAUDE_PLUGIN_ROOT 有設就用，
# 沒設就從腳本自己的位置往上一層推。
ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  ROOT="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
fi
[ -n "$ROOT" ] && [ -f "$ROOT/.claude-plugin/plugin.json" ] || exit 0

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

# ---------- 小工具 ----------

have() { command -v "$1" >/dev/null 2>&1; }

http_get() { # $1 = url，內容印到 stdout
  if have curl; then
    curl -fsSL --connect-timeout 3 --max-time 6 -H 'Cache-Control: no-cache' "$1" 2>/dev/null
  elif have wget; then
    wget -qO- --timeout=6 --tries=1 "$1" 2>/dev/null
  else
    return 1
  fi
}

http_download() { # $1 = url, $2 = 存檔路徑
  if have curl; then
    curl -fsSL --max-time 60 -o "$2" "$1" 2>/dev/null
  elif have wget; then
    wget -qO "$2" --timeout=60 --tries=1 "$1" 2>/dev/null
  else
    return 1
  fi
}

emit() { # $1 = 給使用者看的一句話, $2 = 給 Claude 的指示
  printf '%s\n\n%s\n' "$1" "$2"
}

pick_version() { # 從 stdin 的 plugin.json 內容挑出 version
  grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/' \
    | tr -cd '0-9A-Za-z.+-'
}

read_version() { # $1 = plugin.json 路徑
  [ -f "$1" ] || return 1
  pick_version < "$1"
}

ver_gt() { # $1 > $2 ?
  [ "$1" = "$2" ] && return 1
  local IFS=.
  # shellcheck disable=SC2206
  local a=($1) b=($2)
  local i x y
  for ((i = 0; i < ${#a[@]} || i < ${#b[@]}; i++)); do
    x="${a[i]:-0}"; y="${b[i]:-0}"
    x="${x%%[!0-9]*}"; y="${y%%[!0-9]*}"
    x="${x:-0}"; y="${y:-0}"
    if [ "$((10#$x))" -gt "$((10#$y))" ]; then return 0; fi
    if [ "$((10#$x))" -lt "$((10#$y))" ]; then return 1; fi
  done
  return 1
}

# ---------- 取得遠端內容 ----------

SRC=""   # 一旦拿到完整的檔案樹就設在這裡

ensure_work() {
  [ -n "$WORK" ] && return 0
  WORK="$(mktemp -d 2>/dev/null)" || return 1
}

git_clone_src() { # 備援：沒有 curl／wget／tar 時才走
  have git || return 1
  ensure_work || return 1
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo GCM_INTERACTIVE=never \
    git clone --depth 1 --quiet "$GIT_URL" "$WORK/repo" >/dev/null 2>&1 || return 1
  [ -d "$WORK/repo/$PLUGIN_SUBDIR" ] || return 1
  SRC="$WORK/repo/$PLUGIN_SUBDIR"
}

fetch_remote_version() { # 只要版本號，盡量輕
  local v
  v="$(http_get "$RAW_URL" 2>/dev/null | pick_version)"
  if [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
  git_clone_src || return 1
  read_version "$SRC/.claude-plugin/plugin.json"
}

fetch_remote_tree() { # 真的要更新時才下載整包
  [ -n "$SRC" ] && return 0
  if have tar; then
    ensure_work || return 1
    if http_download "$TAR_URL" "$WORK/src.tar.gz"; then
      mkdir -p "$WORK/x" 2>/dev/null
      if tar -xzf "$WORK/src.tar.gz" -C "$WORK/x" >/dev/null 2>&1; then
        local d
        for d in "$WORK/x"/*/"$PLUGIN_SUBDIR"; do
          [ -d "$d" ] && { SRC="$d"; return 0; }
        done
      fi
    fi
  fi
  git_clone_src
}

# ---------- 三種訊息 ----------

MANUAL_STEPS='手動更新方式：在輸入框執行 /plugin marketplace update oakmega-developer，再執行 /plugin 對 oakmega-developer 按 Update，最後完全關閉並重新開啟 Claude Code。'

say_manual() { # $1 = 本機版本, $2 = 遠端版本
  emit \
    "⚠️ OakMega Developer plugin 有新版 $1 → $2，需要手動更新。" \
    "[OakMega Developer plugin 版本檢查] 使用者跑的是 $1，GitHub 上已經是 $2，而這份 plugin 無法自動更新（可能是本機開發用的 checkout，或沒有寫入權限）。請在本次回覆開頭用繁體中文告訴使用者版本落後，並附上這段步驟：$MANUAL_STEPS 在他更新並重啟之前，如果他要用 /web-tool-component 或 oakmega-developer 的任何 skill，先提醒他現在跑的是舊版；他若堅持先做，就照舊版規則做完，不要拒絕。不要自己去改 plugin 快取目錄或本機 checkout。"
}

say_failed() { # $1 = 本機版本, $2 = 遠端版本
  emit \
    "⚠️ OakMega Developer plugin 有新版 $1 → $2，但自動更新失敗，需要手動更新。" \
    "[OakMega Developer plugin 版本檢查] 偵測到新版 $2（本機 $1），自動更新失敗。請在本次回覆開頭用繁體中文告訴使用者，並附上這段步驟：$MANUAL_STEPS 不要自己去改 plugin 快取目錄。"
}

say_updated() { # $1 = 舊版本, $2 = 新版本
  emit \
    "🔄 OakMega Developer plugin 已自動更新 $1 → $2，請完全關閉並重新開啟 Claude Code 才會生效。" \
    "[OakMega Developer plugin 版本檢查] 剛剛把磁碟上的 plugin 檔案從 $1 換成了 $2。這個 session 目前記憶體裡載入的規則還是換檔案之前的版本，要重啟 Claude Code 才會載入 $2。請在本次回覆的最開頭用繁體中文告訴使用者：plugin 已更新到 $2，建議完全關閉並重新開啟 Claude Code。他若要繼續用 /web-tool-component 或 oakmega-developer 的 skill，就照現在載入的規則做完，不要拒絕。另外：/plugin 畫面顯示的版本號可能對不上，實際檔案以 $2 為準。這則訊息只會出現這一次，不要重複執行更新，也不要自己去改 plugin 快取目錄。"
}

# ---------- 開始 ----------

CUR_VER="$(read_version "$ROOT/.claude-plugin/plugin.json")" || CUR_VER=""
[ -n "$CUR_VER" ] || exit 0

# 1. 問遠端版本
REMOTE_VER="$(fetch_remote_version)" || REMOTE_VER=""
if [ -z "$REMOTE_VER" ]; then
  # 連不上（離線、沒有 curl／wget／git）→ 安靜跳過，不猜
  exit 0
fi

if ! ver_gt "$REMOTE_VER" "$CUR_VER"; then
  exit 0
fi

# 2. 這份 plugin 能不能被我們動？
#    只動 Claude Code 自己的 plugin 快取目錄；開發用的本機 checkout 一律不碰。
CAN_WRITE=1
case "$ROOT" in
  */plugins/cache/*/*/*) : ;;
  *) CAN_WRITE=0 ;;
esac
[ -d "$ROOT/.git" ] && CAN_WRITE=0
[ -w "$ROOT" ] && [ -w "$(dirname "$ROOT")" ] || CAN_WRITE=0

if [ "$CAN_WRITE" = "0" ]; then
  say_manual "$CUR_VER" "$REMOTE_VER"
  exit 0
fi

# 3. 下載整包
if ! fetch_remote_tree || [ -z "$SRC" ]; then
  say_failed "$CUR_VER" "$REMOTE_VER"
  exit 0
fi

# 以實際下載到的檔案為準（raw 與 tarball 可能差幾秒的 CDN 快取）
NEW_VER="$(read_version "$SRC/.claude-plugin/plugin.json")" || NEW_VER=""
[ -n "$NEW_VER" ] || NEW_VER="$REMOTE_VER"
if ! ver_gt "$NEW_VER" "$CUR_VER"; then
  exit 0
fi

# 4. 換檔案。用 rename swap：舊目錄的 inode 會活到本腳本讀完為止，
#    直接 cp 覆蓋正在執行中的自己則會壞掉。
PARENT="$(dirname "$ROOT")"
rm -rf "$PARENT"/.oakmega-new.* "$PARENT"/.oakmega-old.* 2>/dev/null || true
NEW="$PARENT/.oakmega-new.$$"
OLD="$PARENT/.oakmega-old.$$"

FAILED=0
cp -R "$SRC" "$NEW" >/dev/null 2>&1 || FAILED=1
if [ "$FAILED" = "0" ]; then
  # 保留 Claude Code 自己放的標記檔
  for marker in .in_use .orphaned_at; do
    [ -e "$ROOT/$marker" ] && cp -p "$ROOT/$marker" "$NEW/$marker" 2>/dev/null
  done
  if mv "$ROOT" "$OLD" >/dev/null 2>&1; then
    if mv "$NEW" "$ROOT" >/dev/null 2>&1; then
      rm -rf "$OLD" 2>/dev/null
    else
      mv "$OLD" "$ROOT" >/dev/null 2>&1
      FAILED=1
    fi
  else
    FAILED=1
  fi
fi
rm -rf "$NEW" 2>/dev/null || true

if [ "$FAILED" = "1" ]; then
  say_failed "$CUR_VER" "$NEW_VER"
  exit 0
fi

say_updated "$CUR_VER" "$NEW_VER"
exit 0
