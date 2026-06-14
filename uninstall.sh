#!/usr/bin/env bash
# 卸载：从 ~/.claude/settings.json 中移除 statusLine 配置。
# 不删除 skill 目录本身。

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  echo "无 settings.json，无需卸载。"
  exit 0
fi

ts=$(date +%Y%m%d-%H%M%S)
cp "$SETTINGS" "${SETTINGS}.bak-${ts}"

tmp=$(mktemp)
jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✅ 已移除 statusLine 配置。备份 → ${SETTINGS}.bak-${ts}"
