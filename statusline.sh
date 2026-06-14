#!/bin/bash
# 中文化 ccusage 状态行 +
#   🧠 上下文剩余%
#   ⚡ 最近 5 小时额度剩余% (含重置时间)
#   📅 本周额度剩余% (含重置时间)
#
# 数据源：Claude Code 官方 statusline JSON (context_window / rate_limits)
# 若字段缺失（如尚未发出第一次请求 / 非 Pro/Max 订阅），自动回退到原来的"基于时间窗口"算法。

input=$(cat)

# 调试用：保留最近一次官方 JSON 输入，方便核对实际字段名
printf '%s' "$input" >| /tmp/claude-statusline-input.json 2>/dev/null

# === 1) ccusage 原始输出（成本、$/小时 等）===
raw=$(printf '%s' "$input" | bunx ccusage statusline "$@" 2>/dev/null)

# === 2) 解析官方 JSON 字段 ===
have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

ctx_pct=""
five_used=""
five_reset_epoch=""
week_used=""
week_reset_epoch=""

if [[ $have_jq -eq 1 ]]; then
  # 上下文剩余%
  ctx_pct=$(printf '%s' "$input" | jq -r '
    .context_window.remaining_percentage //
    (if (.context_window.used_percentage // null) != null
     then 100 - .context_window.used_percentage else empty end) //
    empty
  ' 2>/dev/null)

  # 5 小时窗口
  five_used=$(printf '%s' "$input" | jq -r '
    .rate_limits.five_hour.used_percentage //
    .rate_limits.five_hour_window.used_percentage //
    empty
  ' 2>/dev/null)
  five_reset_epoch=$(printf '%s' "$input" | jq -r '
    .rate_limits.five_hour.resets_at //
    .rate_limits.five_hour_window.resets_at //
    empty
  ' 2>/dev/null)

  # 周窗口（官方可能叫 seven_day 或 weekly）
  week_used=$(printf '%s' "$input" | jq -r '
    .rate_limits.seven_day.used_percentage //
    .rate_limits.weekly.used_percentage //
    .rate_limits.week.used_percentage //
    empty
  ' 2>/dev/null)
  week_reset_epoch=$(printf '%s' "$input" | jq -r '
    .rate_limits.seven_day.resets_at //
    .rate_limits.weekly.resets_at //
    .rate_limits.week.resets_at //
    empty
  ' 2>/dev/null)
fi

fmt_reset() {
  local epoch="$1"
  [[ -z "$epoch" || "$epoch" == "null" ]] && return
  date -j -r "$epoch" "+%-m/%-d %H:%M" 2>/dev/null
}

# 5h 窗口的重置时间一定在当天 / 次日凌晨，只显示 HH:MM 即可
fmt_reset_short() {
  local epoch="$1"
  [[ -z "$epoch" || "$epoch" == "null" ]] && return
  date -j -r "$epoch" "+%H:%M" 2>/dev/null
}

round_int() { awk -v x="$1" 'BEGIN{printf "%.0f", x}'; }

# --- 上下文 ---
ctx_str=""
if [[ -n "$ctx_pct" && "$ctx_pct" != "null" ]]; then
  ctx_str="🧠 上下文剩$(round_int "$ctx_pct")%"
fi

# --- 5 小时额度 ---
five_str=""
if [[ -n "$five_used" && "$five_used" != "null" ]]; then
  remain=$(awk -v u="$five_used" 'BEGIN{printf "%.0f", 100 - u}')
  reset_at=$(fmt_reset_short "$five_reset_epoch")
  if [[ -n "$reset_at" ]]; then
    five_str="⚡ 5h剩${remain}% →${reset_at}"
  else
    five_str="⚡ 5h剩${remain}%"
  fi
else
  # fallback: 5 小时段时间剩余比例（原逻辑）
  block_json=$(bunx ccusage blocks --active --json 2>/dev/null)
  if [[ -n "$block_json" ]]; then
    endIso=$(printf '%s' "$block_json"   | jq -r '.blocks[0].endTime   // empty' 2>/dev/null)
    startIso=$(printf '%s' "$block_json" | jq -r '.blocks[0].startTime // empty' 2>/dev/null)
    if [[ -n "$endIso" && -n "$startIso" ]]; then
      end_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "${endIso%.*}" +%s 2>/dev/null)
      start_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "${startIso%.*}" +%s 2>/dev/null)
      now_epoch=$(date +%s)
      if [[ -n "$end_epoch" && -n "$start_epoch" ]]; then
        total=$((end_epoch - start_epoch))
        remaining=$((end_epoch - now_epoch))
        (( remaining < 0 )) && remaining=0
        pct=0
        (( total > 0 )) && pct=$((remaining * 100 / total))
        local_end=$(date -j -r "$end_epoch" "+%H:%M")
        five_str="⏰ 段剩${pct}%时 (重置${local_end})"
      fi
    fi
  fi
  [[ -z "$five_str" ]] && five_str="⏰ 无活动段"
fi

# --- 周额度 ---
week_str=""
if [[ -n "$week_used" && "$week_used" != "null" ]]; then
  remain=$(awk -v u="$week_used" 'BEGIN{printf "%.0f", 100 - u}')
  reset_at=$(fmt_reset "$week_reset_epoch")
  if [[ -n "$reset_at" ]]; then
    week_str="📅 周剩${remain}% →${reset_at}"
  else
    week_str="📅 周剩${remain}%"
  fi
else
  # fallback: 本周时间剩余比例（原逻辑，按周一到下周一）
  weekday=$(date +%u)
  today_str=$(date "+%Y-%m-%d")
  today_start=$(date -j -f "%Y-%m-%d %H:%M:%S" "${today_str} 00:00:00" +%s)
  monday_start=$(( today_start - (weekday - 1) * 86400 ))
  week_end=$(( monday_start + 7 * 86400 ))
  now_epoch=$(date +%s)
  week_remaining=$(( week_end - now_epoch ))
  (( week_remaining < 0 )) && week_remaining=0
  week_pct=$(( week_remaining * 100 / (7 * 86400) ))
  week_str="📅 周剩${week_pct}%时"
fi

# === 3) 翻译 ccusage 英文标签 ===
translated=$(printf '%s' "$raw" | sed -E \
  -e 's/\$([0-9.-]+) session/本次 \$\1/g' \
  -e 's/\$([0-9.-]+) today/今日 \$\1/g' \
  -e 's/\$([0-9.-]+) block/当前段 \$\1/g' \
  -e 's/ ?\(no active block\)//g' \
  -e 's/ ?\([0-9]+h [0-9]+m left\)//g' \
  -e 's/ ?\([0-9]+m left\)//g' \
  -e 's/ ?\([0-9]+h left\)//g' \
  -e 's/ ?\(1M context\)//g' \
  -e 's|\$([0-9.]+)/hr|\$\1\/小时|g')

# === 4) 拼接输出：⚡ 5h额度 | 📅 周额度 | ccusage 段 | 🧠 上下文 ===
out=""
[[ -n "$five_str"   ]] && out="${out}${out:+ | }${five_str}"
[[ -n "$week_str"   ]] && out="${out}${out:+ | }${week_str}"
[[ -n "$translated" ]] && out="${out}${out:+ | }${translated}"
# ctx_str 与 ccusage 自带的 🧠 重复，且整行太长会被截断，故不再追加

printf '%s\n' "$out"
