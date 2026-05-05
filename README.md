# oc-go-cc Dashboard

A beautiful web-based monitoring dashboard for [oc-go-cc](https://github.com/samueltuyizere/oc-go-cc) proxy.

oc-go-cc lets you use your [OpenCode Go](https://opencode.ai) subscription with Claude Code. This dashboard provides real-time monitoring, model switching, circuit breaker management, and more — all through an intuitive web interface.

<p align="center">
  <img src="screenshots/dashboard.png" alt="Dashboard Screenshot" width="800">
</p>

## Features

### 📊 Real-time Monitoring
- **6 key metrics** — total requests, success/failure counts, P95/P99 latency, streaming requests
- **Trend arrows** — compare current vs previous poll, see ↑↓ changes instantly
- **5-second auto-refresh** with pause toggle

### ⚡ Circuit Breaker Management
- Per-model status indicators (green=closed, red=open, yellow=half-open)
- Overall health percentage
- One-click reset all circuit breakers

### 📈 Visual Analytics
- **Model usage bar chart** — distribution of requests across models
- **Latency trend line chart** — last 60 requests with P95 reference line
- **Request timeline** — recent 30 requests with status, model, and latency

### 🎛️ Model Configuration
- 6 routing scenarios, each independently configurable
- **Preset system** — save/load/delete model configurations
- Includes two presets: `develop` (all deepseek-v4-pro) and `economy` (kimi/glm/qwen mix)

### 📝 Log Viewer
- Search and keyword highlighting
- Quick filter buttons (All / Errors / Warnings / Success)
- Auto-follow mode

### 🎨 UI
- Dark/light theme toggle
- Chinese (中文) interface
- Zero external dependencies — pure Python + vanilla HTML/CSS/JS
- Browser notifications for circuit breaker trips

## Architecture

```
Claude Code ──Anthropic API──▶ oc-go-cc proxy (127.0.0.1:3456) ──OpenAI API──▶ OpenCode Go
                                      │
                                      ├── /health
                                      ├── /v1/messages
                                      └── logs ──▶ Dashboard (127.0.0.1:3457) reads logs & health
```

## Quick Start

### Prerequisites
- macOS (arm64 or amd64)
- Python 3
- An [OpenCode Go](https://opencode.ai/auth) API key (`sk-opencode-...`)

### Install

```bash
# Set your API key
export OC_GO_CC_API_KEY=sk-opencode-your-key-here

# Clone and install
git clone https://github.com/YOUR_USERNAME/oc-go-cc-dashboard.git
cd oc-go-cc-dashboard
./install.sh
```

After installation:
- **Proxy**: `http://127.0.0.1:3456`
- **Dashboard**: `http://127.0.0.1:3457`

### Configure Claude Code

Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "unused",
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:3456",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-pro"
  }
}
```

Or set environment variables:

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:3456
export ANTHROPIC_AUTH_TOKEN=unused
```

## Usage

```bash
# Open the dashboard in your browser
open http://127.0.0.1:3457

# Or use the alias (if installed via install.sh)
dashboard
```

### Managing the proxy

```bash
oc-go-cc status       # Check proxy status
oc-go-cc stop         # Stop proxy
oc-go-cc serve -b     # Start proxy in background
```

### Managing the dashboard

```bash
oc-go-cc-ui           # Start dashboard (foreground)
oc-go-cc-ui -b        # Start dashboard (background)
oc-go-cc-ui --stop    # Stop dashboard
```

## Routing Scenarios

The proxy auto-selects models based on request context:

| Scenario | Trigger | Default Model |
|----------|---------|---------------|
| `default` | All unmatched requests | deepseek-v4-pro |
| `think` | Prompt contains think/plan | deepseek-v4-pro |
| `complex` | Prompt contains architect/refactor | deepseek-v4-pro |
| `long_context` | Input > 80K tokens | deepseek-v4-pro |
| `background` | Simple tool calls (read, grep) | qwen3.6-plus |
| `fast` | Streaming responses | deepseek-v4-flash |

All configurable via the dashboard or `~/.config/oc-go-cc/config.json`.

## Presets

Two presets are included:

| Preset | Primary Models | Use Case |
|--------|---------------|----------|
| `develop` (开发模式) | deepseek-v4-pro (all scenarios) | Maximum reasoning capability |
| `economy` (省钱模式) | kimi-k2.6 / glm-5.1 / qwen3.6-plus mix | Lower cost, solid performance |

Save your own presets via the dashboard UI or copy JSON files to `~/.config/oc-go-cc/presets/`.

## Manual Installation

If you prefer not to use the install script:

1. **Install oc-go-cc proxy**
   ```bash
   curl -fSL "https://github.com/samueltuyizere/oc-go-cc/releases/latest/download/oc-go-cc_$(uname -m | sed 's/arm64/darwin-arm64/;s/x86_64/darwin-amd64/')" -o ~/.local/bin/oc-go-cc
   chmod +x ~/.local/bin/oc-go-cc
   ```

2. **Initialize config**
   ```bash
   oc-go-cc init
   # Edit ~/.config/oc-go-cc/config.json to add your API key
   ```

3. **Install dashboard**
   ```bash
   cp dashboard/oc-go-cc-ui ~/.local/bin/oc-go-cc-ui
   chmod +x ~/.local/bin/oc-go-cc-ui
   ```

4. **Start services**
   ```bash
   oc-go-cc serve -b
   oc-go-cc-ui -b
   ```

5. **Open dashboard**: http://127.0.0.1:3457

## Directory Structure

```
oc-go-cc-dashboard/
├── README.md
├── install.sh                        # One-click installer
├── .gitignore
├── dashboard/
│   └── oc-go-cc-ui                  # Dashboard Python script (single-file)
├── config/
│   ├── config.example.json          # Example proxy configuration
│   └── presets/
│       ├── 开发模式.json             # "Develop" preset
│       └── 省钱模式.json             # "Economy" preset
└── launchd/
    ├── com.opencode.oc-go-cc.plist             # Proxy auto-start
    └── com.opencode.oc-go-cc-dashboard.plist   # Dashboard auto-start
```

## Security

- **Never commit your API key**. The `.gitignore` excludes `config.json`. Use environment variables (`OC_GO_CC_API_KEY`) or keep your config private.
- All traffic between Claude Code → proxy → OpenCode Go is HTTPS (proxy ↔ OpenCode Go) or localhost (Claude Code ↔ proxy).
- The dashboard binds to `127.0.0.1` only (localhost).

## Tech Stack

- **Backend**: Python 3 `http.server` (stdlib, zero dependencies)
- **Frontend**: Vanilla HTML/CSS/JavaScript (no frameworks, no CDN)
- **Charts**: Canvas API (built into browsers)
- **Proxy**: [oc-go-cc](https://github.com/samueltuyizere/oc-go-cc) by [@samueltuyizere](https://github.com/samueltuyizere)

## License

MIT

## Credits

- [oc-go-cc](https://github.com/samueltuyizere/oc-go-cc) — The proxy that makes this all possible
- [OpenCode](https://opencode.ai) — The AI coding agent platform
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — Anthropic's official CLI tool
