#!/usr/bin/env bash
# oc-go-cc-dashboard — one-click install script
# This script downloads oc-go-cc proxy, installs the dashboard, and configures launchd.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

DASHBOARD_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/oc-go-cc"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"
PRESETS_DIR="$CONFIG_DIR/presets"

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     oc-go-cc Dashboard Installer        ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

# ─── Step 1: Check prerequisites ───
log "Checking prerequisites..."

command -v python3 >/dev/null 2>&1 || err "python3 is required but not installed"
command -v curl >/dev/null 2>&1 || err "curl is required but not installed"

ARCH=$(uname -m)
case "$ARCH" in
  arm64)  BINARY_ARCH="darwin-arm64" ;;
  x86_64) BINARY_ARCH="darwin-amd64" ;;
  *)      err "Unsupported architecture: $ARCH (only macOS arm64/amd64 supported)" ;;
esac
log "Architecture: $ARCH → $BINARY_ARCH"

# ─── Step 2: Download oc-go-cc ───
OC_GO_CC_BIN="$DASHBOARD_DIR/oc-go-cc"

if [ -f "$OC_GO_CC_BIN" ]; then
  warn "oc-go-cc already exists at $OC_GO_CC_BIN"
  read -p "  Re-download? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Skipping oc-go-cc download"
  else
    NEED_DOWNLOAD=1
  fi
else
  NEED_DOWNLOAD=1
fi

if [ -n "$NEED_DOWNLOAD" ]; then
  log "Downloading oc-go-cc ($BINARY_ARCH)..."
  mkdir -p "$DASHBOARD_DIR"
  curl -fSL "https://github.com/samueltuyizere/oc-go-cc/releases/latest/download/oc-go-cc_${BINARY_ARCH}" -o "$OC_GO_CC_BIN"
  chmod +x "$OC_GO_CC_BIN"
  log "oc-go-cc installed: $($OC_GO_CC_BIN --version)"
fi

# ─── Step 3: Install dashboard script ───
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DASHBOARD_BIN="$DASHBOARD_DIR/oc-go-cc-ui"

log "Installing dashboard script..."
cp "$SCRIPT_DIR/dashboard/oc-go-cc-ui" "$DASHBOARD_BIN"
chmod +x "$DASHBOARD_BIN"
log "Dashboard installed: $DASHBOARD_BIN"

# ─── Step 4: Configure ───
log "Setting up configuration..."
mkdir -p "$CONFIG_DIR" "$PRESETS_DIR"

# Initialize oc-go-cc config if not exists
if [ ! -f "$CONFIG_DIR/config.json" ]; then
  log "Initializing oc-go-cc config..."
  "$OC_GO_CC_BIN" init

  # Replace env var with actual key if provided
  if [ -n "$OC_GO_CC_API_KEY" ]; then
    python3 -c "
import json
p = '$CONFIG_DIR/config.json'
c = json.load(open(p))
c['api_key'] = '$OC_GO_CC_API_KEY'
json.dump(c, open(p, 'w'), indent=2)
"
    log "API key configured from OC_GO_CC_API_KEY env var"
  else
    warn "OC_GO_CC_API_KEY not set. Edit $CONFIG_DIR/config.json to add your key."
    warn "Get your key at: https://opencode.ai/auth"
  fi
fi

# Copy example presets
for preset in "$SCRIPT_DIR/config/presets/"*.json; do
  name=$(basename "$preset")
  if [ ! -f "$PRESETS_DIR/$name" ]; then
    cp "$preset" "$PRESETS_DIR/$name"
    log "Preset installed: $name"
  fi
done

# ─── Step 5: Launchd autostart ───
read -p "  Enable auto-start on login? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  log "Installing launchd services..."

  # Update paths in plists
  for plist in "$SCRIPT_DIR/launchd/"*.plist; do
    name=$(basename "$plist")
    dest="$LAUNCHD_DIR/$name"
    # Replace placeholder paths
    sed "s|REPLACE_WITH_HOME|$HOME|g" "$plist" > "$dest"
    launchctl load "$dest" 2>/dev/null || true
    log "Launchd service installed: $name"
  done

  # Inject API key into proxy plist if available
  if [ -n "$OC_GO_CC_API_KEY" ]; then
    /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:OC_GO_CC_API_KEY $OC_GO_CC_API_KEY" \
      "$LAUNCHD_DIR/com.opencode.oc-go-cc.plist" 2>/dev/null || true
  fi
fi

# ─── Step 6: Start services ───
log "Starting services..."
"$OC_GO_CC_BIN" serve -b 2>/dev/null || warn "oc-go-cc already running"
sleep 0.5

# Start dashboard (if not already running)
if ! pgrep -f "oc-go-cc-ui" > /dev/null 2>&1; then
  nohup "$DASHBOARD_BIN" > /dev/null 2>&1 &
  sleep 0.5
fi

# ─── Step 7: Claude Code settings ───
CLAUDE_SETTINGS_DIR=""
read -p "  Auto-configure Claude Code (Opus 4.7 max capability + proxy)? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  CLAUDE_SETTINGS_DIR="$HOME/.claude"
  mkdir -p "$CLAUDE_SETTINGS_DIR"
  CLAUDE_SETTINGS="$CLAUDE_SETTINGS_DIR/settings.json"
  if [ -f "$CLAUDE_SETTINGS" ]; then
    warn "Claude Code settings already exist at $CLAUDE_SETTINGS"
    read -p "  Overwrite? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      cp "$SCRIPT_DIR/config/claude-settings.example.json" "$CLAUDE_SETTINGS"
      log "Claude Code settings overwritten"
    else
      log "Skipped Claude Code settings"
    fi
  else
    cp "$SCRIPT_DIR/config/claude-settings.example.json" "$CLAUDE_SETTINGS"
    log "Claude Code configured: Opus 4.7, max effort, proxy at 127.0.0.1:3456"
  fi
fi

# ─── Step 8: Shell config ───
read -p "  Add aliases to shell config? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  SHELL_RC=""
  case "$SHELL" in
    */zsh)  SHELL_RC="$HOME/.zshrc" ;;
    */bash) SHELL_RC="$HOME/.bashrc" ;;
  esac
  if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
    # Add PATH if not present
    grep -q ".local/bin" "$SHELL_RC" 2>/dev/null || \
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    grep -q "dashboard" "$SHELL_RC" 2>/dev/null || \
      echo 'alias dashboard="open http://127.0.0.1:3457"' >> "$SHELL_RC"
    log "Shell aliases added to $SHELL_RC"
  fi
fi

# ─── Done ───
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          Installation Complete!          ║"
echo "  ╠══════════════════════════════════════════╣"
echo "  ║  Proxy:     http://127.0.0.1:3456       ║"
echo "  ║  Dashboard: http://127.0.0.1:3457       ║"
echo "  ║                                          ║"
echo "  ║  Commands:                               ║"
echo "  ║    dashboard  — open web panel           ║"
echo "  ║    oc-go-cc status                       ║"
echo "  ║    oc-go-cc stop                         ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""
