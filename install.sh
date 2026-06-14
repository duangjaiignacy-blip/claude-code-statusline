#!/usr/bin/env bash
# Claude Code 状态栏显示 - 一键安装脚本
#
# 作用：
#   1. 检查依赖（jq / bun）
#   2. 备份现有的 ~/.claude/settings.json
#   3. 写入 statusLine 配置，指向当前 skill 内的 statusline.sh
#
# 用法：
#   bash <此文件>
#
# 卸载：
#   bash <skill 目录>/uninstall.sh

set -euo pipefail

# === 1) 定位脚本自身 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE_PATH="$SCRIPT_DIR/statusline.sh"

if [[ ! -f "$STATUSLINE_PATH" ]]; then
  echo "❌ 找不到 statusline.sh（应在 $STATUSLINE_PATH）"
  exit 1
fi
chmod +x "$STATUSLINE_PATH"

# === 2) 检查依赖 ===
missing=()
command -v jq    >/dev/null 2>&1 || missing+=("jq")
command -v bunx  >/dev/null 2>&1 || command -v bun >/dev/null 2>&1 || missing+=("bun (含 bunx)")

if (( ${#missing[@]} > 0 )); then
  echo "⚠️  缺少依赖：${missing[*]}"
  echo "    macOS 推荐： brew install jq && brew install oven-sh/bun/bun"
  echo "    依赖缺失时状态栏会以降级模式运行（部分字段为空）。"
  echo "    继续安装？[y/N] "
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "已取消"; exit 1; }
fi

# === 3) 备份并更新 settings.json ===
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"

if [[ -f "$SETTINGS" ]]; then
  ts=$(date +%Y%m%d-%H%M%S)
  cp "$SETTINGS" "${SETTINGS}.bak-${ts}"
  echo "🗂  已备份原配置 → ${SETTINGS}.bak-${ts}"
else
  echo "{}" > "$SETTINGS"
fi

# 用 jq 合并 statusLine 字段，保留其它已有设置
tmp=$(mktemp)
jq --arg cmd "$STATUSLINE_PATH" '
  .statusLine = {
    "type": "command",
    "command": $cmd,
    "refreshInterval": 5
  }
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✅ 已写入 statusLine 配置 → $SETTINGS"
echo "    command = $STATUSLINE_PATH"
echo ""
echo "📺 Claude Code 启动后 5 秒内即可看到新状态栏。"
echo "    如需卸载：bash $SCRIPT_DIR/uninstall.sh"
