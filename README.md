# Claude Code 状态栏显示（中文版）

把 Claude Code 默认状态栏替换成中文化版本，整合 [`ccusage`](https://github.com/ryoppippi/ccusage) 的成本数据，并补充官方 statusline JSON 里的额度字段（5h 窗口剩余、周窗口剩余、各自的重置时间）。

显示效果：

```
⚡ 5h剩98% →19:10 | 📅 周剩100% →6/15 19:00 | 🤖 Opus 4.7 | 💰 本次 $0.06 / 今日 $15.45 / 当前段 $3.89 | 🔥 $6.80/小时 | 🧠 813 (0%)
```

字段说明：

| 字段 | 含义 |
| --- | --- |
| `⚡ 5h剩X% →HH:MM` | 5 小时窗口的额度剩余 % 与重置时间 |
| `📅 周剩X% →M/D HH:MM` | 七日窗口的额度剩余 % 与重置时间 |
| `🤖 Opus 4.7` | 当前模型（已去除冗长的 `(1M context)` 后缀） |
| `💰 本次 / 今日 / 当前段` | 三种聚合维度的累计花费 |
| `🔥 $X/小时` | 当前小时的燃烧速率 |
| `🧠 N (X%)` | 上下文使用量（tokens / 占比） |

## 安装

### 方式一：作为 Claude Code Skill（推荐）

```bash
# 1. 把仓库 clone 到 ~/.claude/skills/ 目录下
git clone https://github.com/duangjaiignacy-blip/kunkun.git ~/.claude/skills/claude-code-statusline

# 2. 一键安装（会自动备份并修改 ~/.claude/settings.json）
bash ~/.claude/skills/claude-code-statusline/install.sh
```

`install.sh` 会：
1. 检查依赖（`jq` / `bun`），缺失时提示
2. 备份现有 `~/.claude/settings.json` 为 `settings.json.bak-<时间戳>`
3. 用 `jq` **合并**写入 `statusLine` 字段，不会覆盖你的其它已有设置
4. 把 `command` 指向 skill 内的 `statusline.sh`（用 `$BASH_SOURCE` 推断绝对路径，因此目录可放在任何位置）

5 秒内 Claude Code 会自动刷新状态栏。

### 方式二：当作纯 statusline 脚本用

如果你不用 Claude Code Skill 系统，也可以直接用脚本本体：

```bash
# 把脚本放到任意位置
curl -fsSL https://raw.githubusercontent.com/duangjaiignacy-blip/kunkun/main/statusline.sh \
  -o ~/.claude/statusline-zh.sh
chmod +x ~/.claude/statusline-zh.sh
```

然后在 `~/.claude/settings.json` 里加上：

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/<你>/.claude/statusline-zh.sh",
    "refreshInterval": 5
  }
}
```

## 卸载

```bash
bash ~/.claude/skills/claude-code-statusline/uninstall.sh
```

只移除 `~/.claude/settings.json` 中的 `statusLine` 字段，**不删除 skill 目录**。要彻底删干净再加一句 `rm -rf ~/.claude/skills/claude-code-statusline`。

## 依赖

| 依赖 | 是否必需 | 缺失影响 |
| --- | --- | --- |
| macOS | 必需 | 脚本使用了 BSD 风格的 `date -j -r`；Linux 需要把它改成 GNU 的 `date -d @epoch` |
| [`jq`](https://stedolan.github.io/jq/) | 必需 | 解析官方 statusline JSON；缺失会导致 5h/周字段无法获取 |
| [`bun`](https://bun.sh/) / `bunx` | 必需 | 用于运行 `ccusage`；缺失则成本字段为空 |
| Claude Code Pro / Max 订阅 | 推荐 | 官方 JSON 只在订阅用户中下发 `rate_limits` 字段；否则脚本会回退到"基于时间窗口剩余比例"的估算 |

## 自定义字段

要增删字段或改顺序，编辑 `statusline.sh` 末尾的拼接段：

```bash
out=""
[[ -n "$five_str"   ]] && out="${out}${out:+ | }${five_str}"
[[ -n "$week_str"   ]] && out="${out}${out:+ | }${week_str}"
[[ -n "$translated" ]] && out="${out}${out:+ | }${translated}"
```

**注意**：整行总长度建议控制在 ~160 字符以内，否则在窄一些的终端 / IDE 里会被截断（这正是当初做这个脚本要解决的问题）。脚本默认刻意省去了"上下文剩余 %"的二次显示（与 ccusage 自带的 `🧠 N (X%)` 重复），就是为了避免截断。

## 调试

每次刷新时，Claude Code 传给脚本的原始 JSON 会被保存到 `/tmp/claude-statusline-input.json`，方便你核对字段名是否变化。手动跑一次：

```bash
cat /tmp/claude-statusline-input.json | bash ~/.claude/skills/claude-code-statusline/statusline.sh
```

## 文件结构

```
claude-code-statusline/
├── SKILL.md         # 给 Claude Code agent 看的触发说明
├── README.md        # 本文件（给人看的项目说明）
├── LICENSE          # MIT
├── statusline.sh    # 状态栏脚本本体
├── install.sh       # 一键安装：备份 settings.json + 写入 statusLine 配置
└── uninstall.sh     # 卸载：从 settings.json 移除 statusLine 字段
```

## License

[MIT](./LICENSE)
