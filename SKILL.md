---
name: claude-code-statusline
description: Claude Code 状态栏显示 — 中文化 ccusage 输出，附加 5h/周额度剩余与重置时间，自动控制长度避免被截断。包含一键安装/卸载脚本。
version: 1.0.0
authors:
  - mac
---

## 概述

把 Claude Code 默认状态栏替换成中文化版本，整合 `ccusage` 的成本数据，并补充官方 statusline JSON 里的额度字段：

```
⚡ 5h剩98% →19:10 | 📅 周剩100% →6/15 19:00 | 🤖 Opus 4.7 | 💰 本次 $0.06 / 今日 $15.45 / 当前段 $3.89 | 🔥 $6.80/小时 | 🧠 813 (0%)
```

字段说明：
- `⚡ 5h剩X% →HH:MM` — 5 小时窗口的额度剩余 % 与重置时间
- `📅 周剩X% →M/D HH:MM` — 七日窗口的额度剩余 % 与重置时间
- `🤖 Opus 4.7` — 当前模型（由 ccusage 提供，已去除冗长的 `(1M context)` 后缀）
- `💰 本次 / 今日 / 当前段` — 三种聚合维度的花费
- `🔥 $X/小时` — 当前小时燃烧速率
- `🧠 N (X%)` — 上下文使用量（tokens 数 / 占比，来自 ccusage）

## 触发场景

当用户出现以下需求时应激活本 skill：

1. **想要中文化的 Claude Code 状态栏**（"把状态栏改成中文"、"汉化 ccusage"）
2. **状态栏被截断 / 显示不全 / 太长**
3. **想看额度剩余 / 重置时间在状态栏里**
4. **想修改状态栏字段、调整顺序、增减 emoji**
5. **在新机器上重新部署同款状态栏**

## 安装

```bash
bash ~/.claude/skills/claude-code-statusline/install.sh
```

脚本会：
1. 检查依赖（`jq`、`bun` / `bunx`），缺失时提示用户
2. 备份现有 `~/.claude/settings.json` 为 `settings.json.bak-<时间戳>`
3. 用 `jq` 合并写入 `statusLine` 字段，**保留其它已有配置**
4. 把 `command` 指向 skill 内的 `statusline.sh`（用 `$BASH_SOURCE` 推断绝对路径，因此 skill 目录可放在任何位置）

5 秒内 Claude Code 会自动刷新状态栏。

## 卸载

```bash
bash ~/.claude/skills/claude-code-statusline/uninstall.sh
```

只移除 `settings.json` 中的 `statusLine` 字段，**不删除 skill 目录**。

## 文件结构

```
claude-code-statusline/
├── SKILL.md           # 本文件
├── statusline.sh      # 状态栏脚本本体（被 Claude Code 周期性调用）
├── install.sh         # 安装：备份 settings.json + 写入 statusLine 配置
└── uninstall.sh       # 卸载：从 settings.json 中移除 statusLine 字段
```

## 依赖

- **macOS** — `statusline.sh` 使用了 BSD 风格的 `date -j -r`，在 Linux 上需要替换为 GNU `date -d @epoch`
- **`jq`** — 解析官方 JSON 字段。缺失则脚本进入降级模式（5h / 周字段会基于"时间窗口剩余比例"估算，准确度下降）
- **`bun` / `bunx`** — 用于运行 `ccusage`。缺失则成本字段为空
- **Claude Code Pro / Max 订阅** — 官方 statusline JSON 才会下发 `rate_limits` 字段；非订阅用户脚本会自动回退到基于时间的估算

## 修改字段

如果要增删字段或改顺序，编辑 `statusline.sh` 末尾的拼接段：

```bash
out=""
[[ -n "$five_str"   ]] && out="${out}${out:+ | }${five_str}"
[[ -n "$week_str"   ]] && out="${out}${out:+ | }${week_str}"
[[ -n "$translated" ]] && out="${out}${out:+ | }${translated}"
```

注意：**整行总长度建议控制在 ~160 字符以内**，否则在窄一些的终端 / IDE 内会被截断。脚本默认刻意省去了"上下文剩余%"的二次显示（与 ccusage 自带的 `🧠 N (X%)` 重复），就是为了避免截断。

## 调试

每次刷新时，Claude Code 给脚本的原始 JSON 会被保存到 `/tmp/claude-statusline-input.json`，方便核对字段名是否变化。
