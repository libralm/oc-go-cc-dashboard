# oc-go-cc Dashboard

一个美观的 Web 监控面板，为 [oc-go-cc](https://github.com/samueltuyizere/oc-go-cc) 代理提供可视化管理。

oc-go-cc 让你用 [OpenCode Go](https://opencode.ai) 订阅驱动 Claude Code。本 Dashboard 提供实时监控、模型切换、熔断器管理、API Key 管理、用量统计等功能。

## Features

### 📊 实时监控
- **6 项核心指标** — 总请求、成功/失败数、P95/P99 延迟、流式请求
- **趋势箭头** — 对比上次轮询，显示 ↑↓ 变化
- **5 秒自动刷新**，支持暂停

### 🔑 API Key 管理（多 Key + 自动切换）
- 从面板添加多个 OpenCode Go API Key
- 当前激活的 Key 绿色标识，已耗尽的红色标识
- **自动故障转移**：后台监控日志，检测到 `429` / `insufficient_quota` 后自动切换到下一个可用 Key
- Key 遮罩显示，前端不暴露完整 Key

### 📈 用量统计
- 今日 Token 消耗进度条（绿→黄→红）
- 按模型细分的 Token 用量 + 请求次数
- 基于 $10/月套餐的预算估算
- 数据持久化到本地 `usage.json`

### ⚡ 熔断器管理
- 每模型独立状态指示（绿=正常、红=熔断、黄=半开）
- 整体健康度百分比
- 一键重置所有熔断器

### 📈 可视化分析
- **模型用量柱状图** — 各模型请求分布
- **延迟趋势折线图** — 最近 60 次请求 + P95 参考线
- **请求时间线** — 最近 30 条，彩色标签区分成功/失败

### 🎛️ 模型配置
- 6 个路由场景独立配置模型
- **预设系统** — 保存/加载/删除多套模型配置
- 预装两个预设：`开发模式`（全 deepseek-v4-pro）和 `省钱模式`（混用 kimi/glm/qwen）

### 📝 日志查看
- 搜索和关键字高亮
- 快捷筛选（全部/错误/警告/成功）
- 自动跟随模式

### 🎨 UI
- 深色/浅色主题切换
- 全中文界面
- 零外部依赖 — 纯 Python + 原生 HTML/CSS/JS
- 浏览器通知（熔断器打开或错误率 > 50% 时告警）

### 🚀 Claude Code 配置模板
- 预置 `claude-settings.example.json`，一键让 Claude Code 以 Opus 4.7 模式运行
- `effort: max` 最大化推理能力
- `install.sh` 可自动配置 Claude Code

## Architecture

```
Claude Code ──Anthropic API──▶ oc-go-cc proxy (127.0.0.1:3456) ──OpenAI API──▶ OpenCode Go
                                      │
                                      ├── /health
                                      ├── /v1/messages
                                      └── logs ──▶ Dashboard (127.0.0.1:3457)
                                                       │
                                                       ├── 实时指标 + 熔断器
                                                       ├── 模型用量 + 延迟趋势
                                                       ├── API Key 管理 + 自动切换
                                                       └── 配置预设 + 日志搜索
```

## Quick Start

### Prerequisites
- macOS (arm64 or amd64)
- Python 3
- 一个 [OpenCode Go](https://opencode.ai/auth) API Key（格式 `sk-opencode-...`）

### 一键安装

```bash
# 设置 API Key
export OC_GO_CC_API_KEY=sk-opencode-your-key-here

# 克隆并安装
git clone https://github.com/libralm/oc-go-cc-dashboard.git
cd oc-go-cc-dashboard
./install.sh
```

安装过程会自动完成：
- ✅ 下载 oc-go-cc 代理
- ✅ 安装 Dashboard 脚本
- ✅ 初始化配置文件
- ✅ 设置 launchd 开机自启
- ✅ 可选：自动配置 Claude Code（Opus 4.7 + max effort）
- ✅ 可选：添加 shell 别名

安装完成后：
- **代理**: `http://127.0.0.1:3456`
- **面板**: `http://127.0.0.1:3457`

## Claude Code 配置

本仓库包含 `config/claude-settings.example.json`，配置了 Claude Code 的最高能力模式：

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "unused",
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:3456",
    "ANTHROPIC_MODEL": "claude-opus-4-7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-opus-4-7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-opus-4-7"
  },
  "effort": "max",
  "permissionMode": "bypassPermissions",
  "verbose": true
}
```

> Claude Code 以为是 Opus 4.7，实际 API 请求走 oc-go-cc 代理 → OpenCode Go。
> 代理不看模型名，只看请求内容路由。所以填任何模型名都不影响实际使用的后端模型。

## 使用

```bash
# 浏览器打开面板
open http://127.0.0.1:3457

# 或用别名
dashboard
```

### 管理代理

```bash
oc-go-cc status       # 查看状态
oc-go-cc stop         # 停止
oc-go-cc serve -b     # 后台启动
```

### 管理面板

```bash
oc-go-cc-ui           # 前台启动
oc-go-cc-ui -b        # 后台启动
oc-go-cc-ui --stop    # 停止
```

## 路由场景

代理根据请求内容自动选择模型（可在面板中随时修改）：

| 场景 | 触发条件 | 默认模型 |
|------|----------|----------|
| `default` | 所有未匹配的请求 | deepseek-v4-pro |
| `think` | 提示词含 think/plan | deepseek-v4-pro |
| `complex` | 提示词含 architect/refactor | deepseek-v4-pro |
| `long_context` | 输入 > 80K token | deepseek-v4-pro |
| `background` | 文件读取等简单操作 | qwen3.6-plus |
| `fast` | 流式响应 | deepseek-v4-flash |

## 预设

预装两个预设：

| 预设 | 主要模型 | 用途 |
|------|----------|------|
| `开发模式` | 全部 deepseek-v4-pro | 最强推理能力 |
| `省钱模式` | kimi-k2.6 / glm-5.1 / qwen3.6-plus 混用 | 降低成本 |

可通过面板 UI 保存自定义预设，或手动复制 JSON 文件到 `~/.config/oc-go-cc/presets/`。

## API Key 自动故障转移

工作原理：
1. 后台线程每 15 秒扫描代理日志
2. 检测到 `429` / `insufficient_quota` / `exceeded your current quota`
3. 连续 3 次配额错误后，标记当前 Key 为"已耗尽"
4. 自动激活下一个可用 Key，重启代理
5. 前端实时显示切换次数

Key 数据存储结构（`~/.config/oc-go-cc/keys.json`）：
```json
{
  "keys": [
    {"key": "sk-xxx", "label": "主账号", "exhausted": false},
    {"key": "sk-yyy", "label": "备用", "exhausted": true}
  ],
  "active_index": 0
}
```

## 手动安装

如果不使用 install.sh：

1. **安装 oc-go-cc 代理**
   ```bash
   curl -fSL "https://github.com/samueltuyizere/oc-go-cc/releases/latest/download/oc-go-cc_$(uname -m | sed 's/arm64/darwin-arm64/;s/x86_64/darwin-amd64/')" -o ~/.local/bin/oc-go-cc
   chmod +x ~/.local/bin/oc-go-cc
   ```

2. **初始化配置**
   ```bash
   oc-go-cc init
   # 编辑 ~/.config/oc-go-cc/config.json 填入 API Key
   ```

3. **安装面板**
   ```bash
   cp dashboard/oc-go-cc-ui ~/.local/bin/oc-go-cc-ui
   chmod +x ~/.local/bin/oc-go-cc-ui
   ```

4. **启动服务**
   ```bash
   oc-go-cc serve -b
   oc-go-cc-ui -b
   ```

5. **打开面板**: http://127.0.0.1:3457

## 目录结构

```
oc-go-cc-dashboard/
├── README.md
├── install.sh                           # 一键安装脚本
├── .gitignore
├── dashboard/
│   └── oc-go-cc-ui                     # 面板主程序（单文件 Python）
├── config/
│   ├── config.example.json             # 代理配置模板
│   ├── claude-settings.example.json    # Claude Code 配置模板
│   └── presets/
│       ├── 开发模式.json                # 全 deepseek-v4-pro
│       └── 省钱模式.json                # 混用低成本模型
└── launchd/
    ├── com.opencode.oc-go-cc.plist             # 代理开机自启
    └── com.opencode.oc-go-cc-dashboard.plist   # 面板开机自启
```

## 安全

- **不要提交 API Key**。`.gitignore` 已排除 `config.json`。
- 所有流量：Claude Code ↔ 代理（localhost）→ OpenCode Go（HTTPS）
- 面板仅绑定 `127.0.0.1`（仅本机访问）
- API Key 在前端 API 响应中已遮罩（如 `sk-90wSbrT...HFYdC8`）

## 技术栈

- **后端**: Python 3 `http.server`（标准库，零依赖）
- **前端**: 原生 HTML/CSS/JavaScript（零框架，零 CDN）
- **图表**: Canvas API（浏览器内置）
- **代理**: [oc-go-cc](https://github.com/samueltuyizere/oc-go-cc) by [@samueltuyizere](https://github.com/samueltuyizere)

## License

MIT

## Credits

- [oc-go-cc](https://github.com/samueltuyizere/oc-go-cc) — 代理项目
- [OpenCode](https://opencode.ai) — AI 编程平台
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — Anthropic 官方 CLI 工具
