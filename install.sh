#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  OpenClaw — One-line installer & initializer
#  Usage:
#    curl -fsSL https://install9.ai/openclaw | bash
#    curl -fsSL https://install9.ai/openclaw | bash -s -- --help
#
#  Version: 1.1.0
#  License: Apache-2.0
#  Compat:  macOS (arm64/x86_64) · Linux (amd64/arm64)
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

INSTALLER_VERSION="1.1.0"
MIN_NODE_MAJOR=22
OPENCLAW_PKG="openclaw"
OPENCLAW_CONFIG_DIR="$HOME/.openclaw"
OPENCLAW_CONFIG="$OPENCLAW_CONFIG_DIR/openclaw.json"
TOTAL_PHASES=8

# ── CLI arguments ────────────────────────────────────────────────────
NON_INTERACTIVE=false
ARG_CHANNEL=""
ARG_FEISHU_APP_ID=""
ARG_FEISHU_APP_SECRET=""
ARG_FEISHU_DOMAIN="feishu"
ARG_SKIP_SECURITY=false
ARG_SKIP_CHANNEL=false
ARG_SKIP_DEPS=false

# ── Colors & output (defined early so parse_args can use warn) ──────
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

info()    { echo -e "${CYAN}  ▸${NC} $*"; }
ok()      { echo -e "${GREEN}  ✔${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $*"; }
fail()    { echo -e "${RED}  ✖${NC} $*"; exit 1; }
phase()   { echo ""; echo -e "${BOLD}[$1/${TOTAL_PHASES}]${NC} $2"; echo -e "${DIM}  ─────────────────────────────────────────${NC}"; }
divider() { echo -e "${DIM}  ─────────────────────────────────────────${NC}"; }

# ── CLI parsing ──────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
OpenClaw Installer

Usage:
  curl -fsSL https://install9.ai/openclaw | bash
  curl -fsSL https://install9.ai/openclaw | bash -s -- [OPTIONS]

Options:
  --non-interactive            Skip all prompts (use with flags below)
  --channel <name>             Channel to configure (feishu|lark)
  --feishu-app-id <id>         Feishu App ID
  --feishu-app-secret <secret> Feishu App Secret
  --feishu-domain <domain>     feishu (default) or lark
  --skip-channel               Skip channel setup
  --skip-security              Skip security hardening
  --skip-deps                  Skip dependency installation
  -h, --help                   Show this help
  -v, --version                Show installer version
EOF
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --non-interactive)   NON_INTERACTIVE=true ;;
      --channel)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--channel requires a value"; fi
        ARG_CHANNEL="$2"; shift ;;
      --feishu-app-id)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--feishu-app-id requires a value"; fi
        ARG_FEISHU_APP_ID="$2"; shift ;;
      --feishu-app-secret)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--feishu-app-secret requires a value"; fi
        ARG_FEISHU_APP_SECRET="$2"; shift ;;
      --feishu-domain)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--feishu-domain requires a value"; fi
        ARG_FEISHU_DOMAIN="$2"; shift ;;
      --skip-channel)      ARG_SKIP_CHANNEL=true ;;
      --skip-security)     ARG_SKIP_SECURITY=true ;;
      --skip-deps)         ARG_SKIP_DEPS=true ;;
      -h|--help)           usage ;;
      -v|--version)        echo "openclaw-installer $INSTALLER_VERSION"; exit 0 ;;
      *) warn "Unknown option: $1" ;;
    esac
    shift
  done
}

# ── Prompt helpers ───────────────────────────────────────────────────
# All reads go through /dev/tty so curl|bash works with interactive prompts.
# Falls back to stdin if /dev/tty is unavailable (CI container).
_can_tty=false
if { true </dev/tty; } 2>/dev/null; then _can_tty=true; fi

_read_input() {
  # shellcheck disable=SC2162  # -r is passed by caller via "$@"
  if [[ "$_can_tty" == "true" ]]; then
    read "$@" </dev/tty
  else
    read "$@" || true
  fi
}

prompt() {
  local msg="$1" default="${2:-}"
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    echo "$default"
    return
  fi
  local input=""
  if [[ -n "$default" ]]; then
    echo -en "  ${BOLD}${msg}${NC} [${default}]: " >&2
    _read_input -r input
    echo "${input:-$default}"
  else
    while true; do
      echo -en "  ${BOLD}${msg}${NC}: " >&2
      _read_input -r input
      if [[ -n "$input" ]]; then echo "$input"; return; fi
      echo -e "  ${RED}Cannot be empty${NC}" >&2
    done
  fi
}

prompt_optional() {
  local msg="$1" default="${2:-}"
  if [[ "$NON_INTERACTIVE" == "true" ]]; then echo "$default"; return; fi
  local input=""
  echo -en "  ${BOLD}${msg}${NC} [${default}]: " >&2
  _read_input -r input
  echo "${input:-$default}"
}

prompt_secret() {
  local msg="$1"
  if [[ "$NON_INTERACTIVE" == "true" ]]; then echo ""; return; fi
  local input=""
  while true; do
    echo -en "  ${BOLD}${msg}${NC}: " >&2
    _read_input -rs input
    echo >&2
    if [[ -n "$input" ]]; then echo "$input"; return; fi
    echo -e "  ${RED}Cannot be empty${NC}" >&2
  done
}

confirm() {
  if [[ "$NON_INTERACTIVE" == "true" ]]; then return 0; fi
  echo -en "  ${BOLD}$1${NC} [Y/n]: "
  local ans=""
  _read_input -r ans || true
  [[ -z "$ans" || "$ans" =~ ^[Yy] ]]
}

# In non-interactive mode, default to "no" instead of "yes"
confirm_default_no() {
  if [[ "$NON_INTERACTIVE" == "true" ]]; then return 1; fi
  echo -en "  ${BOLD}$1${NC} [y/N]: "
  local ans=""
  _read_input -r ans || true
  [[ "$ans" =~ ^[Yy] ]]
}

# ── Platform helpers ─────────────────────────────────────────────────
OS=""
ARCH=""
PKG_MGR=""
SHELL_RC=""
SHELL_TYPE=""
INIT_SYSTEM=""

detect_platform() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac

  # Package manager (verify command exists, not just OS)
  if [[ "$OS" == "darwin" ]] && command -v brew &>/dev/null; then
    PKG_MGR="brew"
  elif [[ "$OS" == "darwin" ]]; then
    PKG_MGR=""  # macOS without brew
  elif command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
  elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
  elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
  elif command -v pacman &>/dev/null; then
    PKG_MGR="pacman"
  elif command -v apk &>/dev/null; then
    PKG_MGR="apk"
  fi

  # Shell type and RC file
  local current_shell="${SHELL:-/bin/bash}"
  case "$current_shell" in
    */zsh)  SHELL_TYPE="zsh";  SHELL_RC="$HOME/.zshrc" ;;
    */fish) SHELL_TYPE="fish"; SHELL_RC="$HOME/.config/fish/config.fish" ;;
    *)      SHELL_TYPE="bash"; SHELL_RC="$HOME/.bashrc" ;;
  esac

  # Init system
  if [[ "$OS" == "darwin" ]]; then
    INIT_SYSTEM="launchd"
  elif command -v systemctl &>/dev/null; then
    INIT_SYSTEM="systemd"
  fi
}

sed_inplace() {
  if [[ "$OS" == "darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

need_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  elif command -v sudo &>/dev/null; then
    sudo "$@"
  else
    fail "Need root privileges. Run with sudo or as root."
  fi
}

# Safe config reader — passes key via environment variable, not string interpolation
config_read() {
  local key="$1"
  OC_KEY="$key" OC_FILE="$OPENCLAW_CONFIG" node -e '
    try {
      const c = JSON.parse(require("fs").readFileSync(process.env.OC_FILE, "utf8"));
      const keys = process.env.OC_KEY.split(".");
      let v = c;
      for (const k of keys) v = v?.[k];
      const out = v ?? "";
      // For arrays/objects, output JSON; for scalars, output string
      if (typeof out === "object") console.log(JSON.stringify(out));
      else console.log(String(out));
    } catch { console.log(""); }
  ' 2>/dev/null || echo ""
}

config_backup() {
  if [[ -f "$OPENCLAW_CONFIG" ]]; then
    cp "$OPENCLAW_CONFIG" "${OPENCLAW_CONFIG}.bak.$(date +%s)"
  fi
}

retry() {
  local max="$1" delay="$2"; shift 2
  local attempt=1
  while true; do
    if "$@" 2>/dev/null; then return 0; fi
    if [[ $attempt -ge $max ]]; then return 1; fi
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

# Write token to shell RC with correct syntax per shell type
write_token_to_rc() {
  local token="$1"
  mkdir -p "$(dirname "$SHELL_RC")"

  if [[ "$SHELL_TYPE" == "fish" ]]; then
    local fish_line="set -gx OPENCLAW_GATEWAY_TOKEN '${token}'"
    if grep -q "OPENCLAW_GATEWAY_TOKEN" "$SHELL_RC" 2>/dev/null; then
      sed_inplace "s|set -gx OPENCLAW_GATEWAY_TOKEN.*|${fish_line}|" "$SHELL_RC"
    else
      { echo ""; echo "# OpenClaw Gateway Token"; echo "$fish_line"; } >> "$SHELL_RC"
    fi
  else
    local bash_line="export OPENCLAW_GATEWAY_TOKEN='${token}'"
    if grep -q "OPENCLAW_GATEWAY_TOKEN" "$SHELL_RC" 2>/dev/null; then
      sed_inplace "s|export OPENCLAW_GATEWAY_TOKEN=.*|${bash_line}|" "$SHELL_RC"
    else
      { echo ""; echo "# OpenClaw Gateway Token"; echo "$bash_line"; } >> "$SHELL_RC"
    fi
  fi
}

# ── Error handler ────────────────────────────────────────────────────
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}  Installation interrupted (exit $exit_code)${NC}"
    echo -e "  Config backups: ${OPENCLAW_CONFIG}.bak.*"
    echo -e "  Logs: ${OPENCLAW_CONFIG_DIR}/logs/"
    echo -e "  Re-run this script to continue from where it stopped."
    echo ""
  fi
}
trap cleanup EXIT

# ══════════════════════════════════════════════════════════════════════
#  PHASE 0: Banner & environment detection
# ══════════════════════════════════════════════════════════════════════
banner() {
  echo ""
  echo -e "${BOLD}  ╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}  ║${NC}  ${CYAN}OpenClaw${NC} — Installer ${DIM}v${INSTALLER_VERSION}${NC}             ${BOLD}║${NC}"
  echo -e "${BOLD}  ╚══════════════════════════════════════════╝${NC}"
  echo ""
}

phase0_detect() {
  phase "1" "Detecting environment"

  detect_platform

  info "OS: ${OS} (${ARCH})"
  info "Package manager: ${PKG_MGR:-none detected}"
  info "Shell: ${SHELL_TYPE} → ${SHELL_RC}"
  info "Init system: ${INIT_SYSTEM:-unknown}"

  if [[ "$OS" == "darwin" && -z "$PKG_MGR" ]]; then
    warn "Homebrew not found. Install from https://brew.sh for automatic dependency management."
  fi

  # Check existing installation
  if command -v openclaw &>/dev/null; then
    local ver
    ver=$(openclaw --version 2>/dev/null || echo "unknown")
    ok "OpenClaw already installed: ${ver}"
  else
    info "OpenClaw not found — will install"
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 1: Dependencies
# ══════════════════════════════════════════════════════════════════════
install_pkg() {
  local name="$1"
  if [[ -z "$PKG_MGR" ]]; then
    fail "No package manager found. Install '${name}' manually and re-run."
  fi
  info "Installing ${name} via ${PKG_MGR}..."
  case "$PKG_MGR" in
    brew)   brew install "$name" 2>&1 | tail -3 ;;
    apt)    need_sudo apt-get install -y "$name" 2>&1 | tail -1 ;;
    dnf)    need_sudo dnf install -y "$name" 2>&1 | tail -1 ;;
    yum)    need_sudo yum install -y "$name" 2>&1 | tail -1 ;;
    pacman) need_sudo pacman -S --noconfirm "$name" 2>&1 | tail -1 ;;
    apk)    need_sudo apk add "$name" 2>&1 | tail -1 ;;
  esac
}

install_node_via_nvm() {
  info "Installing Node.js ${MIN_NODE_MAJOR} via nvm..."
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    info "Installing nvm first..."
    local nvm_script
    nvm_script=$(mktemp)
    if curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh" -o "$nvm_script"; then
      PROFILE=/dev/null bash "$nvm_script" 2>&1 | tail -3
      rm -f "$nvm_script"
    else
      rm -f "$nvm_script"
      fail "Failed to download nvm installer"
    fi
  fi
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install "$MIN_NODE_MAJOR" 2>&1 | tail -3
  nvm use "$MIN_NODE_MAJOR" 2>/dev/null || true
  nvm alias default "$MIN_NODE_MAJOR" 2>/dev/null || true
}

install_node_via_pkg() {
  case "$PKG_MGR" in
    brew)
      install_pkg "node@${MIN_NODE_MAJOR}"
      ;;
    apt)
      info "Adding NodeSource repository..."
      local setup_script
      setup_script=$(mktemp)
      if curl -fsSL "https://deb.nodesource.com/setup_${MIN_NODE_MAJOR}.x" -o "$setup_script"; then
        need_sudo bash "$setup_script" 2>&1 | tail -3
        rm -f "$setup_script"
        need_sudo apt-get install -y nodejs 2>&1 | tail -1
      else
        rm -f "$setup_script"
        fail "Failed to download NodeSource setup script"
      fi
      ;;
    dnf|yum)
      local setup_script
      setup_script=$(mktemp)
      if curl -fsSL "https://rpm.nodesource.com/setup_${MIN_NODE_MAJOR}.x" -o "$setup_script"; then
        need_sudo bash "$setup_script" 2>&1 | tail -3
        rm -f "$setup_script"
        need_sudo "${PKG_MGR}" install -y nodejs 2>&1 | tail -1
      else
        rm -f "$setup_script"
        fail "Failed to download NodeSource setup script"
      fi
      ;;
    pacman) install_pkg nodejs-lts-jod ;;
    apk)    install_pkg "nodejs~=${MIN_NODE_MAJOR}" ;;
    *)      install_node_via_nvm ;;
  esac
}

phase1_deps() {
  phase "2" "Checking dependencies"

  if [[ "$ARG_SKIP_DEPS" == "true" ]]; then
    info "Skipped (--skip-deps)"
    return
  fi

  # ── git ──
  if command -v git &>/dev/null; then
    ok "git: $(git --version 2>&1 | head -1)"
  else
    install_pkg git
  fi

  # ── curl ──
  if command -v curl &>/dev/null; then
    ok "curl: available"
  else
    install_pkg curl
  fi

  # ── openssl ──
  if command -v openssl &>/dev/null; then
    ok "openssl: available"
  else
    install_pkg openssl
  fi

  # ── jq ──
  if command -v jq &>/dev/null; then
    ok "jq: available"
  else
    install_pkg jq
  fi

  # ── Node.js ──
  local node_ok=false
  if command -v node &>/dev/null; then
    local node_major
    node_major=$(node -e "console.log(process.versions.node.split('.')[0])" 2>/dev/null || echo "0")
    if [[ "$node_major" -ge "$MIN_NODE_MAJOR" ]]; then
      ok "Node.js: $(node --version) (meets >= ${MIN_NODE_MAJOR})"
      node_ok=true
    else
      warn "Node.js $(node --version) is below required v${MIN_NODE_MAJOR}"
    fi
  fi

  if [[ "$node_ok" != "true" ]]; then
    if [[ -n "$PKG_MGR" ]]; then
      echo ""
      info "Node.js ${MIN_NODE_MAJOR}+ is required. Choose install method:"
      echo -e "    1) ${BOLD}nvm${NC} (recommended, user-space)"
      echo -e "    2) ${BOLD}System package manager${NC} (${PKG_MGR})"
      echo ""
      local choice
      choice=$(prompt "Select [1/2]" "1")

      if [[ "$choice" == "2" ]]; then
        install_node_via_pkg
      else
        install_node_via_nvm
      fi
    else
      install_node_via_nvm
    fi

    # Verify
    if command -v node &>/dev/null; then
      local ver
      ver=$(node --version 2>/dev/null)
      ok "Node.js installed: ${ver}"
    else
      fail "Node.js installation failed. Install Node.js ${MIN_NODE_MAJOR}+ manually and re-run."
    fi
  fi

  # ── npm ──
  if command -v npm &>/dev/null; then
    ok "npm: $(npm --version 2>/dev/null)"
  else
    fail "npm not found. It should come with Node.js — check your installation."
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 2: Install OpenClaw
# ══════════════════════════════════════════════════════════════════════
phase2_install() {
  phase "3" "Installing OpenClaw"

  if command -v openclaw &>/dev/null; then
    local current_ver
    current_ver=$(openclaw --version 2>/dev/null || echo "unknown")
    ok "OpenClaw ${current_ver} already installed"

    # In non-interactive mode, don't auto-upgrade (use confirm_default_no)
    if confirm_default_no "Check for updates?"; then
      info "Checking latest version..."
      local latest
      latest=$(npm view "$OPENCLAW_PKG" version 2>/dev/null || echo "")
      if [[ -n "$latest" && "$latest" != "$current_ver" ]]; then
        info "New version available: ${latest} (current: ${current_ver})"
        if confirm "Upgrade to ${latest}?"; then
          npm install -g "${OPENCLAW_PKG}@latest" 2>&1 | tail -3
          ok "Upgraded to $(openclaw --version 2>/dev/null)"
        fi
      else
        ok "Already on latest version"
      fi
    fi
  else
    info "Installing ${OPENCLAW_PKG} globally via npm..."
    npm install -g "$OPENCLAW_PKG" 2>&1 | tail -5
    if command -v openclaw &>/dev/null; then
      ok "OpenClaw $(openclaw --version 2>/dev/null) installed"
    else
      fail "Installation failed. Try: npm install -g ${OPENCLAW_PKG}"
    fi
  fi

  # Locate installation path — prefer current node version
  OC_BIN=$(command -v openclaw 2>/dev/null || echo "")
  OC_ROOT=""
  if [[ -n "$OC_BIN" ]]; then
    OC_ROOT=$(OC_BIN_DIR="$(dirname "$OC_BIN")" node -e "console.log(require('path').resolve(process.env.OC_BIN_DIR, '../lib/node_modules/openclaw'))" 2>/dev/null || echo "")
  fi
  if [[ -z "$OC_ROOT" || ! -d "$OC_ROOT" ]]; then
    # Try the current node's prefix first, then common fallbacks
    local npm_prefix
    npm_prefix=$(npm prefix -g 2>/dev/null || echo "")
    if [[ -n "$npm_prefix" && -d "${npm_prefix}/lib/node_modules/openclaw" ]]; then
      OC_ROOT="${npm_prefix}/lib/node_modules/openclaw"
    else
      for p in \
        /usr/local/lib/node_modules/openclaw \
        /opt/homebrew/lib/node_modules/openclaw \
        "$HOME/.npm-global/lib/node_modules/openclaw"; do
        if [[ -d "$p" ]]; then OC_ROOT="$p"; break; fi
      done
    fi
  fi
  if [[ -z "$OC_ROOT" || ! -d "$OC_ROOT" ]]; then
    fail "Cannot locate openclaw installation directory"
  fi
  ok "Install path: ${OC_ROOT}"
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 3: Initialize configuration
# ══════════════════════════════════════════════════════════════════════
phase3_init() {
  phase "4" "Initializing configuration"

  # Run setup if no config exists
  if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    info "No config found. Running initial setup..."
    mkdir -p "$OPENCLAW_CONFIG_DIR"
    openclaw setup --non-interactive 2>&1 | tail -5 || true

    if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
      info "Creating minimal config..."
      cat > "$OPENCLAW_CONFIG" <<'CONF'
{
  "meta": {},
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 }
    },
    "list": [
      {
        "id": "main",
        "tools": { "profile": "full" }
      }
    ]
  },
  "tools": { "profile": "messaging" },
  "session": { "dmScope": "per-channel-peer" },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },
        "bootstrap-extra-files": { "enabled": true },
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    }
  },
  "channels": {},
  "gateway": {},
  "memory": { "backend": "builtin" },
  "plugins": { "allow": [], "entries": {}, "installs": {} }
}
CONF
      ok "Minimal config created"
    fi
  else
    ok "Config exists: ${OPENCLAW_CONFIG}"
  fi

  # ── Gateway Token ──
  info "Checking gateway token..."

  local auth_token remote_token
  auth_token=$(config_read "gateway.auth.token")
  remote_token=$(config_read "gateway.remote.token")

  GATEWAY_TOKEN=""
  NEED_TOKEN_FIX=false

  if [[ -z "$auth_token" || "$auth_token" == "YOUR_NEW_GATEWAY_TOKEN" ]]; then
    info "Generating new gateway token..."
    GATEWAY_TOKEN=$(openssl rand -hex 32)
    NEED_TOKEN_FIX=true
  elif [[ "$auth_token" != "$remote_token" ]]; then
    info "Syncing auth.token → remote.token..."
    GATEWAY_TOKEN="$auth_token"
    NEED_TOKEN_FIX=true
  else
    GATEWAY_TOKEN="$auth_token"
    ok "Gateway token: configured"
  fi

  if [[ "$NEED_TOKEN_FIX" == "true" ]]; then
    config_backup

    GATEWAY_TOKEN="$GATEWAY_TOKEN" OC_FILE="$OPENCLAW_CONFIG" node -e '
      const fs = require("fs");
      const f = process.env.OC_FILE;
      const config = JSON.parse(fs.readFileSync(f, "utf8"));
      if (!config.gateway) config.gateway = {};
      if (!config.gateway.auth) config.gateway.auth = {};
      config.gateway.auth.mode = "token";
      config.gateway.auth.token = process.env.GATEWAY_TOKEN;
      if (!config.gateway.remote) config.gateway.remote = {};
      config.gateway.remote.token = process.env.GATEWAY_TOKEN;
      fs.writeFileSync(f, JSON.stringify(config, null, 2) + "\n");
    '

    ok "Gateway token: set"

    write_token_to_rc "$GATEWAY_TOKEN"
    ok "Token written to ${SHELL_RC}"
  fi

  export OPENCLAW_GATEWAY_TOKEN="${GATEWAY_TOKEN}"

  # ── Workspace directory ──
  local workspace
  workspace=$(config_read "agents.defaults.workspace")
  workspace="${workspace/#\~/$HOME}"
  if [[ -n "$workspace" ]]; then
    mkdir -p "$workspace" 2>/dev/null || true
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 4: Gateway service
# ══════════════════════════════════════════════════════════════════════
phase4_gateway() {
  phase "5" "Setting up gateway service"

  # Install service
  info "Installing gateway service..."
  openclaw gateway install --force 2>&1 | grep -v "^$" | head -3 || true

  # Start/restart
  info "Starting gateway..."
  openclaw gateway restart 2>&1 | head -1 || true

  # Verify connection with retries
  info "Verifying gateway connection..."
  if retry 5 3 openclaw cron list; then
    ok "Gateway: running and connected"
  else
    warn "Gateway connection timed out"
    warn "Try: openclaw gateway restart && openclaw status"
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 5: Channel setup
# ══════════════════════════════════════════════════════════════════════

# ── Feishu / Lark ──
setup_channel_feishu() {
  local feishu_ext="${OC_ROOT}/extensions/feishu"

  if [[ ! -d "$feishu_ext" ]]; then
    warn "Feishu extension not found at ${feishu_ext}, skipping"
    return
  fi

  # Install SDK dependency
  if [[ ! -d "${feishu_ext}/node_modules/@larksuiteoapi/node-sdk" ]]; then
    info "Installing @larksuiteoapi/node-sdk..."
    (cd "$feishu_ext" && npm install @larksuiteoapi/node-sdk --save 2>&1 | tail -1)
    ok "Feishu SDK installed"
  else
    ok "Feishu SDK: present"
  fi

  # Check existing config
  local existing_app_id
  existing_app_id=$(config_read "channels.feishu.appId")

  local skip_config=false
  if [[ -n "$existing_app_id" ]]; then
    warn "Feishu already configured (App ID: ${existing_app_id})"
    if ! confirm "Reconfigure?"; then
      skip_config=true
    fi
  fi

  if [[ "$skip_config" != "true" ]]; then
    echo ""
    echo -e "  ${CYAN}Feishu App Setup Guide:${NC}"
    echo -e "    1. Go to ${BOLD}https://open.feishu.cn${NC}"
    echo -e "    2. Create an app → get ${YELLOW}App ID${NC} and ${YELLOW}App Secret${NC}"
    echo -e "    3. Enable permissions: Send/Read messages"
    echo -e "    4. Events: Use ${BOLD}WebSocket${NC} (persistent connection) mode"
    echo ""

    local app_id app_secret domain

    # Use CLI args or prompt
    if [[ -n "$ARG_FEISHU_APP_ID" ]]; then
      app_id="$ARG_FEISHU_APP_ID"
    else
      app_id=$(prompt "App ID" "${existing_app_id:-}")
    fi

    if [[ -n "$ARG_FEISHU_APP_SECRET" ]]; then
      app_secret="$ARG_FEISHU_APP_SECRET"
    else
      app_secret=$(prompt_secret "App Secret")
    fi

    if [[ -z "$app_secret" ]]; then
      warn "No App Secret provided, skipping Feishu setup"
      return
    fi

    # Validate format
    if [[ ! "$app_id" =~ ^cli_[a-zA-Z0-9]{14,}$ ]]; then
      warn "App ID format may be incorrect (expected: cli_xxxxxxxxxxxxxxxx)"
    fi

    # Domain
    if [[ "$NON_INTERACTIVE" != "true" && -z "$ARG_FEISHU_APP_ID" ]]; then
      echo ""
      echo -e "    1) ${BOLD}feishu${NC} — China mainland"
      echo -e "    2) ${BOLD}lark${NC}   — International"
      echo ""
      local domain_choice
      domain_choice=$(prompt "Select [1/2]" "1")
      domain=$([[ "$domain_choice" == "2" ]] && echo "lark" || echo "feishu")
    else
      domain="$ARG_FEISHU_DOMAIN"
    fi

    # Write config (pass secrets via env, never interpolation)
    config_backup
    FEISHU_APP_ID="$app_id" \
    FEISHU_APP_SECRET="$app_secret" \
    FEISHU_DOMAIN="$domain" \
    OC_FILE="$OPENCLAW_CONFIG" \
    node -e '
      const fs = require("fs");
      const f = process.env.OC_FILE;
      const config = JSON.parse(fs.readFileSync(f, "utf8"));

      if (!config.channels) config.channels = {};
      config.channels.feishu = {
        enabled: true,
        appId: process.env.FEISHU_APP_ID,
        appSecret: process.env.FEISHU_APP_SECRET,
        connectionMode: "websocket",
        domain: process.env.FEISHU_DOMAIN,
        groupPolicy: "open"
      };

      if (!config.plugins) config.plugins = {};
      if (!config.plugins.allow) config.plugins.allow = [];
      if (!config.plugins.allow.includes("feishu")) config.plugins.allow.push("feishu");
      if (!config.plugins.entries) config.plugins.entries = {};
      config.plugins.entries.feishu = { enabled: true };

      fs.writeFileSync(f, JSON.stringify(config, null, 2) + "\n");
    '

    ok "Feishu config written"
  fi

  # Restart gateway to load plugin
  info "Restarting gateway to load Feishu plugin..."
  openclaw gateway restart 2>&1 | head -1 || true
  sleep 5

  # Verify
  local status_out
  status_out=$(openclaw status 2>&1 || true)
  if echo "$status_out" | grep -qi "feishu.*OK"; then
    ok "Feishu channel: active"
  else
    warn "Feishu may need a moment to connect. Check: openclaw status"
  fi

  # Optional test message
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    if confirm "Send a test message to verify?"; then
      local sessions_file="$OPENCLAW_CONFIG_DIR/agents/main/sessions/sessions.json"
      local open_id=""

      if [[ -f "$sessions_file" ]]; then
        open_id=$(grep -Eo 'ou_[a-zA-Z0-9_]{32,}' "$sessions_file" 2>/dev/null | head -1 || echo "")
      fi

      if [[ -n "$open_id" ]]; then
        info "Detected Open ID: ${open_id}"
        open_id=$(prompt "Confirm Open ID" "$open_id")
      else
        warn "No Open ID found. Send a message to your bot in Feishu first,"
        warn "then re-run or use: openclaw message send --channel feishu --target <id> --message test"
        open_id=$(prompt_optional "Open ID (empty to skip)" "")
      fi

      if [[ -n "$open_id" ]]; then
        local result
        result=$(openclaw message send \
          --channel feishu \
          --target "$open_id" \
          --message "OpenClaw installed successfully! This is a test message." 2>&1 || true)

        if echo "$result" | grep -q "Sent"; then
          ok "Test message sent! Check Feishu."
        else
          warn "Send may have failed: $(echo "$result" | grep -E "rror|ail" | tail -1 || echo "$result" | tail -1)"
        fi
      fi
    fi
  fi
}

phase5_channel() {
  phase "6" "Channel setup"

  if [[ "$ARG_SKIP_CHANNEL" == "true" ]]; then
    info "Skipped (--skip-channel)"
    return
  fi

  local channel="$ARG_CHANNEL"
  if [[ -z "$channel" && "$NON_INTERACTIVE" != "true" ]]; then
    echo ""
    echo -e "  Available channels:"
    echo -e "    1) ${BOLD}feishu${NC}  — Feishu / Lark"
    echo -e "    2) ${DIM}telegram${NC} — Telegram ${DIM}(coming soon)${NC}"
    echo -e "    3) ${DIM}slack${NC}    — Slack ${DIM}(coming soon)${NC}"
    echo -e "    4) ${DIM}discord${NC}  — Discord ${DIM}(coming soon)${NC}"
    echo -e "    5) ${DIM}wechat${NC}   — WeChat Work ${DIM}(coming soon)${NC}"
    echo -e "    s) Skip"
    echo ""
    local choice
    choice=$(prompt "Select channel" "1")
    case "$choice" in
      1|feishu) channel="feishu" ;;
      s|S)      channel="skip" ;;
      *)        warn "Not yet supported, skipping"; channel="skip" ;;
    esac
  fi

  case "$channel" in
    feishu|lark) setup_channel_feishu ;;
    skip|"")     info "No channel configured" ;;
    *)           warn "Channel '${channel}' is not yet supported" ;;
  esac
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 6: Security hardening & cleanup
# ══════════════════════════════════════════════════════════════════════
phase6_security() {
  phase "7" "Security hardening & cleanup"

  if [[ "$ARG_SKIP_SECURITY" == "true" ]]; then
    info "Skipped (--skip-security)"
    return
  fi

  if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    warn "No config file, skipping"
    return
  fi

  config_backup
  local fixes=0

  # ── Fix denyCommands ──
  local deny_commands
  deny_commands=$(config_read "gateway.nodes.denyCommands")
  if [[ -n "$deny_commands" ]]; then
    OC_FILE="$OPENCLAW_CONFIG" node -e '
      const fs = require("fs");
      const f = process.env.OC_FILE;
      const config = JSON.parse(fs.readFileSync(f, "utf8"));
      if (config.gateway?.nodes?.denyCommands) {
        const valid = [
          "system.run", "system.eval",
          "canvas.eval", "canvas.present", "canvas.navigate",
          "canvas.a2ui.push", "canvas.a2ui.pushJSONL", "canvas.a2ui.reset"
        ];
        const current = config.gateway.nodes.denyCommands;
        const cleaned = current.filter(c => valid.includes(c));
        config.gateway.nodes.denyCommands = cleaned.length > 0
          ? cleaned
          : ["system.run", "system.eval"];
      }
      fs.writeFileSync(f, JSON.stringify(config, null, 2) + "\n");
    ' 2>/dev/null && { ok "denyCommands: cleaned up invalid entries"; fixes=$((fixes + 1)); } || true
  fi

  # ── Set workspaceOnly for filesystem safety ──
  local ws_only
  ws_only=$(config_read "tools.fs.workspaceOnly")
  if [[ "$ws_only" != "true" ]]; then
    OC_FILE="$OPENCLAW_CONFIG" node -e '
      const fs = require("fs");
      const f = process.env.OC_FILE;
      const config = JSON.parse(fs.readFileSync(f, "utf8"));
      if (!config.tools) config.tools = {};
      if (!config.tools.fs) config.tools.fs = {};
      config.tools.fs.workspaceOnly = true;
      fs.writeFileSync(f, JSON.stringify(config, null, 2) + "\n");
    ' 2>/dev/null && { ok "tools.fs.workspaceOnly: enabled"; fixes=$((fixes + 1)); } || true
  fi

  # ── Disable memory search if no embedding provider ──
  local mem_enabled
  mem_enabled=$(config_read "agents.defaults.memorySearch.enabled")
  if [[ "$mem_enabled" != "false" ]]; then
    if [[ -z "${OPENAI_API_KEY:-}" && -z "${GEMINI_API_KEY:-}" && -z "${VOYAGE_API_KEY:-}" ]]; then
      OC_FILE="$OPENCLAW_CONFIG" node -e '
        const fs = require("fs");
        const f = process.env.OC_FILE;
        const config = JSON.parse(fs.readFileSync(f, "utf8"));
        if (!config.agents) config.agents = {};
        if (!config.agents.defaults) config.agents.defaults = {};
        if (!config.agents.defaults.memorySearch) config.agents.defaults.memorySearch = {};
        config.agents.defaults.memorySearch.enabled = false;
        fs.writeFileSync(f, JSON.stringify(config, null, 2) + "\n");
      ' 2>/dev/null && {
        ok "memorySearch: disabled (no embedding provider found)"
        info "To enable: set OPENAI_API_KEY or configure an embedding provider"
        fixes=$((fixes + 1))
      } || true
    fi
  fi

  # ── Clean orphan session files ──
  local sessions_dir="$OPENCLAW_CONFIG_DIR/agents/main/sessions"
  local sessions_json="${sessions_dir}/sessions.json"
  if [[ -d "$sessions_dir" && -f "$sessions_json" ]]; then
    local orphans=0
    local _old_nullglob
    _old_nullglob=$(shopt -p nullglob 2>/dev/null || true)
    shopt -s nullglob
    for f in "${sessions_dir}"/*.jsonl; do
      local session_id
      session_id=$(basename "$f" .jsonl)
      # Use exact JSON string match to avoid substring false positives
      if ! grep -qF "\"${session_id}\"" "$sessions_json" 2>/dev/null; then
        rm -f "$f"
        orphans=$((orphans + 1))
      fi
    done
    eval "$_old_nullglob"
    if [[ $orphans -gt 0 ]]; then
      ok "Cleaned ${orphans} orphan session file(s)"
      fixes=$((fixes + 1))
    fi
  fi

  # ── Log rotation hint ──
  if [[ -f "$OPENCLAW_CONFIG_DIR/logs/gateway.log" ]]; then
    local log_size
    log_size=$(wc -c < "$OPENCLAW_CONFIG_DIR/logs/gateway.log" 2>/dev/null | tr -d ' ' || echo 0)
    if [[ "$log_size" -gt 52428800 ]]; then  # > 50MB
      warn "gateway.log is $(( log_size / 1048576 ))MB — consider: > ~/.openclaw/logs/gateway.log"
    fi
  fi

  if [[ $fixes -eq 0 ]]; then
    ok "No issues found"
  else
    ok "${fixes} issue(s) fixed"
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 7: Summary
# ══════════════════════════════════════════════════════════════════════
phase7_summary() {
  phase "8" "Setup complete"

  local oc_version
  oc_version=$(openclaw --version 2>/dev/null || echo "unknown")

  # Detect active channels
  local channels=""
  local feishu_enabled
  feishu_enabled=$(config_read "channels.feishu.enabled")
  if [[ "$feishu_enabled" == "true" ]]; then
    channels="${channels}feishu "
  fi

  local gw_port
  gw_port=$(config_read "gateway.port")
  gw_port="${gw_port:-18789}"

  echo ""
  echo -e "  ${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
  echo -e "  ${GREEN}${BOLD}║${NC}  ${GREEN}OpenClaw is ready!${NC}                     ${GREEN}${BOLD}║${NC}"
  echo -e "  ${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Version:${NC}   ${oc_version}"
  echo -e "  ${BOLD}Config:${NC}    ${OPENCLAW_CONFIG}"
  echo -e "  ${BOLD}Channels:${NC}  ${channels:-none}"
  echo -e "  ${BOLD}Gateway:${NC}   ws://127.0.0.1:${gw_port}"
  echo ""

  divider
  echo -e "  ${BOLD}Quick start:${NC}"
  echo ""
  echo -e "    ${CYAN}openclaw status${NC}              # Health check"
  echo -e "    ${CYAN}openclaw logs --follow${NC}       # Live logs"
  echo -e "    ${CYAN}openclaw tui${NC}                 # Terminal chat UI"
  echo -e "    ${CYAN}openclaw skills list${NC}         # Available skills"
  echo -e "    ${CYAN}openclaw cron list${NC}           # Scheduled jobs"
  echo ""

  if [[ -n "$channels" ]]; then
    divider
    echo -e "  ${BOLD}Messaging:${NC}"
    echo ""
    echo -e "    ${CYAN}openclaw message send --channel feishu \\${NC}"
    echo -e "    ${CYAN}  --target <open_id> --message \"hello\"${NC}"
    echo ""
  fi

  divider
  echo -e "  ${BOLD}Documentation:${NC}  https://docs.openclaw.ai"
  echo -e "  ${BOLD}Dashboard:${NC}      http://127.0.0.1:${gw_port}/"
  echo ""

  if [[ "$NEED_TOKEN_FIX" == "true" ]]; then
    echo -e "  ${YELLOW}${BOLD}Important:${NC} Run ${CYAN}source ~/${SHELL_RC##*/}${NC} or open a new terminal"
    echo -e "  to activate the gateway token in your shell."
    echo ""
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════
main() {
  parse_args "$@"
  banner
  phase0_detect
  phase1_deps
  phase2_install
  phase3_init
  phase4_gateway
  phase5_channel
  phase6_security
  phase7_summary
}

main "$@"
