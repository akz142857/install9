#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  OpenClaw — One-line installer & initializer
#  Usage:
#    curl -fsSL https://install9.ai/openclaw | bash
#    curl -fsSL https://install9.ai/openclaw | bash -s -- --help
#
#  Version: 1.0.0
#  License: Apache-2.0
#  Compat:  macOS (arm64/x86_64) · Linux (amd64/arm64)
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

INSTALLER_VERSION="1.0.0"
MIN_NODE_MAJOR=22
OPENCLAW_PKG="openclaw"
OPENCLAW_CONFIG_DIR="$HOME/.openclaw"
OPENCLAW_CONFIG="$OPENCLAW_CONFIG_DIR/openclaw.json"
TOTAL_PHASES=8
INSTALL9_BIN="$HOME/.local/bin/install9"
INSTALL9_URL="https://install9.ai/openclaw"

# ── CLI arguments ────────────────────────────────────────────────────
NON_INTERACTIVE=false
ARG_CHANNEL=""
ARG_FEISHU_APP_ID=""
ARG_FEISHU_APP_SECRET=""
ARG_FEISHU_DOMAIN="feishu"
ARG_TELEGRAM_BOT_TOKEN=""
ARG_SLACK_BOT_TOKEN=""
ARG_SLACK_APP_TOKEN=""
ARG_DISCORD_BOT_TOKEN=""
ARG_UNINSTALL=false
ARG_SELF_UPDATE=false
ARG_SKIP_SECURITY=false
ARG_SKIP_CHANNEL=false
ARG_SKIP_DEPS=false

# ── Colors & output (defined early so parse_args can use warn) ──────
if { [[ -t 1 ]] || [[ -t 2 ]]; } && [[ "${TERM:-}" != "dumb" ]]; then
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
  install9 [OPTIONS]                          (after first install)

Options:
  --non-interactive            Skip all prompts (use with flags below)
  --channel <name>             Channel to configure (feishu|lark|telegram|slack|discord)
  --feishu-app-id <id>         Feishu App ID
  --feishu-app-secret <secret> Feishu App Secret
  --feishu-domain <domain>     feishu (default) or lark
  --telegram-token <token>     Telegram Bot Token (from @BotFather)
  --slack-bot-token <token>    Slack Bot Token (xoxb-...)
  --slack-app-token <token>    Slack App Token (xapp-..., for Socket Mode)
  --discord-token <token>      Discord Bot Token
  --model-provider <name>      LLM provider (anthropic|openai|openai-codex|google|openrouter|...)
  --model-name <model>         Model name (e.g. claude-sonnet-4-20250514, gpt-4o)
  --model-api-key <key>        API key for the LLM provider
  --model-base-url <url>       Base URL (for openai-compatible provider)
  --skip-model                 Skip model setup
  --uninstall                  Uninstall OpenClaw and clean up
  --self-update                Update the install9 command itself
  --skip-channel               Skip channel setup
  --skip-security              Skip security hardening
  --skip-deps                  Skip dependency installation
  -h, --help                   Show this help
  -v, --version                Show installer version

Environment variables (safer than CLI args for secrets):
  OPENCLAW_MODEL_PROVIDER      LLM provider name
  OPENCLAW_MODEL_API_KEY       LLM provider API key
  OPENCLAW_MODEL_NAME          Model name
  OPENCLAW_MODEL_BASE_URL      Base URL (for openai-compatible)
  OPENCLAW_FEISHU_APP_ID       Feishu App ID
  OPENCLAW_FEISHU_APP_SECRET   Feishu App Secret
  OPENCLAW_TELEGRAM_TOKEN      Telegram Bot Token
  OPENCLAW_SLACK_BOT_TOKEN     Slack Bot Token
  OPENCLAW_SLACK_APP_TOKEN     Slack App Token
  OPENCLAW_DISCORD_TOKEN       Discord Bot Token
EOF
  exit 0
}

parse_args() {
  # Support secrets via environment variables (safer than CLI args visible in ps)
  if [[ -n "${OPENCLAW_MODEL_PROVIDER:-}" ]]; then
    ARG_MODEL_PROVIDER="$OPENCLAW_MODEL_PROVIDER"; unset OPENCLAW_MODEL_PROVIDER
  fi
  if [[ -n "${OPENCLAW_MODEL_API_KEY:-}" ]]; then
    ARG_MODEL_API_KEY="$OPENCLAW_MODEL_API_KEY"; unset OPENCLAW_MODEL_API_KEY
  fi
  if [[ -n "${OPENCLAW_MODEL_NAME:-}" ]]; then
    ARG_MODEL_NAME="$OPENCLAW_MODEL_NAME"; unset OPENCLAW_MODEL_NAME
  fi
  if [[ -n "${OPENCLAW_MODEL_BASE_URL:-}" ]]; then
    ARG_MODEL_BASE_URL="$OPENCLAW_MODEL_BASE_URL"; unset OPENCLAW_MODEL_BASE_URL
  fi
  if [[ -n "${OPENCLAW_FEISHU_APP_ID:-}" ]]; then
    ARG_FEISHU_APP_ID="$OPENCLAW_FEISHU_APP_ID"; unset OPENCLAW_FEISHU_APP_ID
  fi
  if [[ -n "${OPENCLAW_FEISHU_APP_SECRET:-}" ]]; then
    ARG_FEISHU_APP_SECRET="$OPENCLAW_FEISHU_APP_SECRET"; unset OPENCLAW_FEISHU_APP_SECRET
  fi
  if [[ -n "${OPENCLAW_TELEGRAM_TOKEN:-}" ]]; then
    ARG_TELEGRAM_BOT_TOKEN="$OPENCLAW_TELEGRAM_TOKEN"; unset OPENCLAW_TELEGRAM_TOKEN
  fi
  if [[ -n "${OPENCLAW_SLACK_BOT_TOKEN:-}" ]]; then
    ARG_SLACK_BOT_TOKEN="$OPENCLAW_SLACK_BOT_TOKEN"; unset OPENCLAW_SLACK_BOT_TOKEN
  fi
  if [[ -n "${OPENCLAW_SLACK_APP_TOKEN:-}" ]]; then
    ARG_SLACK_APP_TOKEN="$OPENCLAW_SLACK_APP_TOKEN"; unset OPENCLAW_SLACK_APP_TOKEN
  fi
  if [[ -n "${OPENCLAW_DISCORD_TOKEN:-}" ]]; then
    ARG_DISCORD_BOT_TOKEN="$OPENCLAW_DISCORD_TOKEN"; unset OPENCLAW_DISCORD_TOKEN
  fi

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
      --telegram-token)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--telegram-token requires a value"; fi
        ARG_TELEGRAM_BOT_TOKEN="$2"; shift ;;
      --slack-bot-token)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--slack-bot-token requires a value"; fi
        ARG_SLACK_BOT_TOKEN="$2"; shift ;;
      --slack-app-token)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--slack-app-token requires a value"; fi
        ARG_SLACK_APP_TOKEN="$2"; shift ;;
      --discord-token)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--discord-token requires a value"; fi
        ARG_DISCORD_BOT_TOKEN="$2"; shift ;;
      --model-provider)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--model-provider requires a value"; fi
        ARG_MODEL_PROVIDER="$2"; shift ;;
      --model-name)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--model-name requires a value"; fi
        ARG_MODEL_NAME="$2"; shift ;;
      --model-api-key)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--model-api-key requires a value"; fi
        ARG_MODEL_API_KEY="$2"; shift ;;
      --model-base-url)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then fail "--model-base-url requires a value"; fi
        ARG_MODEL_BASE_URL="$2"; shift ;;
      --skip-model)        ARG_SKIP_MODEL=true ;;
      --uninstall)         ARG_UNINSTALL=true ;;
      --self-update)       ARG_SELF_UPDATE=true ;;
      --skip-channel)      ARG_SKIP_CHANNEL=true ;;
      --skip-security)     ARG_SKIP_SECURITY=true ;;
      --skip-deps)         ARG_SKIP_DEPS=true ;;
      -h|--help)           usage ;;
      -v|--version)        echo "openclaw-installer $INSTALLER_VERSION"; exit 0 ;;
      *)
        if [[ "$NON_INTERACTIVE" == "true" ]]; then
          fail "Unknown option: $1"
        else
          warn "Unknown option: $1"
        fi ;;

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
    */zsh)        SHELL_TYPE="zsh";  SHELL_RC="$HOME/.zshrc" ;;
    */fish)       SHELL_TYPE="fish"; SHELL_RC="$HOME/.config/fish/config.fish" ;;
    */csh|*/tcsh) SHELL_TYPE="csh";  SHELL_RC="$HOME/.cshrc" ;;
    *)            SHELL_TYPE="bash"; SHELL_RC="$HOME/.bashrc" ;;
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
    local bak="${OPENCLAW_CONFIG}.bak.$(date +%s)"
    cp "$OPENCLAW_CONFIG" "$bak"
    chmod 600 "$bak" 2>/dev/null || true
    # Keep only the last 5 backups
    # shellcheck disable=SC2012
    ls -1t "${OPENCLAW_CONFIG}".bak.* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
  fi
}

harden_config() {
  chmod 700 "$OPENCLAW_CONFIG_DIR" 2>/dev/null || true
  chmod 600 "$OPENCLAW_CONFIG" 2>/dev/null || true
}

# Atomic config write — takes a Node.js script that modifies `config` object.
# Writes to a temp file then renames, preventing partial writes from race conditions.
config_write() {
  local node_script="$1"
  OC_FILE="$OPENCLAW_CONFIG" node -e '
    const fs = require("fs"), path = require("path");
    const f = process.env.OC_FILE;
    const config = JSON.parse(fs.readFileSync(f, "utf8"));
    '"$node_script"'
    const tmp = f + ".tmp." + process.pid;
    fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
    fs.renameSync(tmp, f);
  '
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

# Write token to shell RC with correct syntax per shell type.
# Uses delete+append instead of sed substitution to avoid metacharacter issues in tokens.
write_env_to_rc() {
  local var_name="$1" value="$2" comment="$3"
  local safe_value="${value//\'/\'\\\'\'}"
  mkdir -p "$(dirname "$SHELL_RC")"

  # Remove existing lines for this variable (sed is a safe no-op if pattern absent)
  if [[ -f "$SHELL_RC" ]]; then
    sed_inplace -e "/# ${comment}/d" -e "/${var_name}/d" "$SHELL_RC"
  fi

  local rc_line=""
  case "$SHELL_TYPE" in
    fish) rc_line="set -gx ${var_name} '${safe_value}'" ;;
    csh)  rc_line="setenv ${var_name} '${safe_value}'" ;;
    *)    rc_line="export ${var_name}='${safe_value}'" ;;
  esac
  { echo ""; echo "# ${comment}"; echo "$rc_line"; } >> "$SHELL_RC"
}

write_token_to_rc() {
  write_env_to_rc "OPENCLAW_GATEWAY_TOKEN" "$1" "OpenClaw Gateway Token"
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
#  PHASE 1: Banner & environment detection
# ══════════════════════════════════════════════════════════════════════
banner() {
  echo ""
  echo -e "${BOLD}  ╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}  ║${NC}  ${CYAN}OpenClaw${NC} — Installer ${DIM}v${INSTALLER_VERSION}${NC}             ${BOLD}║${NC}"
  echo -e "${BOLD}  ╚══════════════════════════════════════════╝${NC}"
  echo ""
}

phase1_detect() {
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
#  PHASE 2: Dependencies
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
    if curl -fsSL --connect-timeout 15 --max-time 120 "https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh" -o "$nvm_script"; then
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
      if curl -fsSL --connect-timeout 15 --max-time 120 "https://deb.nodesource.com/setup_${MIN_NODE_MAJOR}.x" -o "$setup_script"; then
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
      if curl -fsSL --connect-timeout 15 --max-time 120 "https://rpm.nodesource.com/setup_${MIN_NODE_MAJOR}.x" -o "$setup_script"; then
        need_sudo bash "$setup_script" 2>&1 | tail -3
        rm -f "$setup_script"
        need_sudo "${PKG_MGR}" install -y nodejs 2>&1 | tail -1
      else
        rm -f "$setup_script"
        fail "Failed to download NodeSource setup script"
      fi
      ;;
    # NOTE: "jod" is the Node 22 LTS codename — update when MIN_NODE_MAJOR changes
    pacman) install_pkg nodejs-lts-jod ;;
    apk)    install_pkg "nodejs~=${MIN_NODE_MAJOR}" ;;
    *)      install_node_via_nvm ;;
  esac
}

phase2_deps() {
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
    local node_major node_ver_str
    node_ver_str=$(node --version 2>/dev/null || echo "v0")
    node_major="${node_ver_str#v}"
    node_major="${node_major%%.*}"
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
#  PHASE 3: Install OpenClaw
# ══════════════════════════════════════════════════════════════════════
phase3_install() {
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
          local npm_pfx
          npm_pfx=$(npm prefix -g 2>/dev/null || echo "")
          if [[ -n "$npm_pfx" && ! -w "$npm_pfx" ]]; then
            need_sudo npm install -g "${OPENCLAW_PKG}@latest" 2>&1 | tail -3
          else
            npm install -g "${OPENCLAW_PKG}@latest" 2>&1 | tail -3
          fi
          ok "Upgraded to $(openclaw --version 2>/dev/null)"
        fi
      else
        ok "Already on latest version"
      fi
    fi
  else
    info "Installing ${OPENCLAW_PKG} globally via npm..."
    # Check if npm global directory is writable (system Node.js may need sudo)
    local npm_prefix
    npm_prefix=$(npm prefix -g 2>/dev/null || echo "")
    if [[ -n "$npm_prefix" && ! -w "$npm_prefix" ]]; then
      warn "npm global directory (${npm_prefix}) is not writable"
      info "Installing with elevated privileges..."
      need_sudo npm install -g "$OPENCLAW_PKG" 2>&1 | tail -5
    else
      npm install -g "$OPENCLAW_PKG" 2>&1 | tail -5
    fi
    if command -v openclaw &>/dev/null; then
      ok "OpenClaw $(openclaw --version 2>/dev/null) installed"
    else
      fail "Installation failed. Try: sudo npm install -g ${OPENCLAW_PKG}"
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
#  PHASE 4: Initialize configuration
# ══════════════════════════════════════════════════════════════════════
phase4_init() {
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
      harden_config
      ok "Minimal config created"
    fi
  else
    ok "Config exists: ${OPENCLAW_CONFIG}"
  fi
  harden_config

  # ── Model Setup ──
  if [[ "$ARG_SKIP_MODEL" != "true" ]]; then
    local existing_model
    existing_model=$(config_read "agents.defaults.model.primary")

    if [[ -n "$existing_model" && -z "${ARG_MODEL_PROVIDER:-}" ]]; then
      ok "Model: ${existing_model} (already configured)"
    else
      local provider="${ARG_MODEL_PROVIDER:-}"
      local model_name="${ARG_MODEL_NAME:-}"

      # Interactive provider selection
      if [[ -z "$provider" && "$NON_INTERACTIVE" != "true" ]]; then
        echo ""
        echo -e "  Select LLM provider:"
        echo -e "    1)  ${BOLD}anthropic${NC}          — Claude"
        echo -e "    2)  ${BOLD}openai${NC}             — GPT / o-series"
        echo -e "    3)  ${BOLD}openai-codex${NC}       — Codex (ChatGPT Plus OAuth)"
        echo -e "    4)  ${BOLD}google${NC}             — Gemini"
        echo -e "    5)  ${BOLD}openrouter${NC}         — OpenRouter (100+ models)"
        echo -e "    6)  ${BOLD}xai${NC}                — Grok"
        echo -e "    7)  ${BOLD}mistral${NC}            — Mistral"
        echo -e "    8)  ${BOLD}groq${NC}               — Groq (fast inference)"
        echo -e "    9)  ${BOLD}minimax${NC}            — MiniMax"
        echo -e "    10) ${BOLD}zai${NC}                — GLM / ChatGLM (Zhipu AI)"
        echo -e "    11) ${BOLD}ollama${NC}             — Local models (no API key)"
        echo -e "    12) ${BOLD}openai-compatible${NC}  — Custom endpoint"
        echo -e "    s)  Skip"
        echo ""
        local choice
        choice=$(prompt "Select provider" "1")
        case "$choice" in
          1|anthropic)         provider="anthropic" ;;
          2|openai)            provider="openai" ;;
          3|openai-codex|codex) provider="openai-codex" ;;
          4|google)            provider="google" ;;
          5|openrouter)        provider="openrouter" ;;
          6|xai)               provider="xai" ;;
          7|mistral)           provider="mistral" ;;
          8|groq)              provider="groq" ;;
          9|minimax)           provider="minimax" ;;
          10|zai|glm)          provider="zai" ;;
          11|ollama)           provider="ollama" ;;
          12|openai-compatible) provider="openai-compatible" ;;
          s|S)                 provider="" ;;
          *)                   warn "Unknown choice, skipping model setup"; provider="" ;;
        esac
      fi

      if [[ -n "$provider" ]]; then
        # Default model and example hints per provider
        local default_model="" model_hints=""
        case "$provider" in
          anthropic)         default_model="claude-sonnet-4";       model_hints="claude-opus-4, claude-haiku-4" ;;
          openai)            default_model="gpt-4o";                model_hints="gpt-4o-mini, o3, o4-mini" ;;
          openai-codex)      default_model="codex-mini-latest";     model_hints="o4-mini" ;;
          google)            default_model="gemini-2.5-flash";      model_hints="gemini-2.5-pro, gemini-2.0-flash" ;;
          openrouter)        default_model="anthropic/claude-sonnet-4"; model_hints="openai/gpt-4o, deepseek/deepseek-chat" ;;
          xai)               default_model="grok-3";                model_hints="grok-3-mini" ;;
          mistral)           default_model="mistral-large-latest";  model_hints="codestral-latest, mistral-medium-latest" ;;
          groq)              default_model="llama-3.3-70b-versatile"; model_hints="llama-3.1-8b-instant, mixtral-8x7b-32768" ;;
          minimax)           default_model="MiniMax-M2.5";          model_hints="MiniMax-M2.5-highspeed" ;;
          zai)               default_model="glm-4-plus";            model_hints="glm-4-air, glm-4-flash" ;;
          ollama)            default_model="llama3.3";              model_hints="qwen2.5-coder:32b, deepseek-r1:32b" ;;
          openai-compatible) default_model="" ;;
        esac

        # Prompt for model name (or use CLI arg / fallback default)
        if [[ -z "$model_name" ]]; then
          if [[ "$NON_INTERACTIVE" != "true" ]]; then
            if [[ -n "$model_hints" ]]; then
              info "Other models: ${model_hints}"
            fi
            model_name=$(prompt "Model name" "$default_model")
          else
            model_name="$default_model"
          fi
        fi

        # Guard: openai-compatible requires a model name
        if [[ -z "$model_name" ]]; then
          if [[ "$provider" == "openai-compatible" ]]; then
            warn "No model name provided for openai-compatible; skipping model setup"
            provider=""
          fi
        fi

        # Build primary model identifier: "provider/model"
        local model_primary="${provider}/${model_name}"

        # Determine API key env var name (per OpenClaw docs)
        local api_key_var="" needs_api_key=true
        case "$provider" in
          anthropic)         api_key_var="ANTHROPIC_API_KEY" ;;
          openai)            api_key_var="OPENAI_API_KEY" ;;
          openai-codex)      needs_api_key=false ;;  # OAuth via ChatGPT Plus
          google)            api_key_var="GEMINI_API_KEY" ;;
          openrouter)        api_key_var="OPENROUTER_API_KEY" ;;
          xai)               api_key_var="XAI_API_KEY" ;;
          mistral)           api_key_var="MISTRAL_API_KEY" ;;
          groq)              api_key_var="GROQ_API_KEY" ;;
          minimax)           api_key_var="MINIMAX_API_KEY" ;;
          zai)               api_key_var="ZAI_API_KEY" ;;
          ollama)            needs_api_key=false ;;  # Local, no key needed
          openai-compatible) api_key_var="OPENAI_API_KEY" ;;
        esac

        # Get API key
        local api_key="${ARG_MODEL_API_KEY:-}"
        if [[ "$needs_api_key" == "true" ]]; then
          if [[ -z "$api_key" && -n "$api_key_var" ]]; then
            api_key="${!api_key_var:-}"
          fi
          if [[ -z "$api_key" && "$NON_INTERACTIVE" != "true" && -n "$api_key_var" ]]; then
            api_key=$(prompt_secret "${api_key_var}")
          fi
        fi

        # Special note for OAuth-based providers
        if [[ "$provider" == "openai-codex" && "$NON_INTERACTIVE" != "true" ]]; then
          info "Codex uses ChatGPT Plus OAuth — run 'openclaw auth login' after install"
        fi

        # Base URL for openai-compatible
        local base_url="${ARG_MODEL_BASE_URL:-}"
        if [[ "$provider" == "openai-compatible" && -z "$base_url" && "$NON_INTERACTIVE" != "true" ]]; then
          base_url=$(prompt "Base URL (e.g. https://api.example.com/v1)")
        fi

        # Write model config to openclaw.json
        config_backup
        MODEL_PRIMARY="$model_primary" MODEL_BASE_URL="${base_url:-}" config_write '
          if (!config.agents) config.agents = {};
          if (!config.agents.defaults) config.agents.defaults = {};
          if (!config.agents.defaults.model) config.agents.defaults.model = {};
          config.agents.defaults.model.primary = process.env.MODEL_PRIMARY;
          if (process.env.MODEL_BASE_URL) config.agents.defaults.model.baseUrl = process.env.MODEL_BASE_URL;
          else delete config.agents.defaults.model.baseUrl;
        '
        harden_config
        ok "Model: ${model_primary}"

        # Write API key to shell RC
        if [[ "$needs_api_key" == "true" ]]; then
          if [[ -n "$api_key" && -n "$api_key_var" ]]; then
            write_env_to_rc "$api_key_var" "$api_key" "OpenClaw LLM API Key"
            export "${api_key_var}=${api_key}"
            ok "API key written to ${SHELL_RC}"
          elif [[ -n "$api_key_var" ]]; then
            warn "No API key provided — set ${api_key_var} before starting OpenClaw"
          fi
        fi
      fi
    fi
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

    GATEWAY_TOKEN="$GATEWAY_TOKEN" config_write '
      if (!config.gateway) config.gateway = {};
      config.gateway.mode = "local";
      if (!config.gateway.auth) config.gateway.auth = {};
      config.gateway.auth.mode = "token";
      config.gateway.auth.token = process.env.GATEWAY_TOKEN;
      if (!config.gateway.remote) config.gateway.remote = {};
      config.gateway.remote.token = process.env.GATEWAY_TOKEN;
    '

    harden_config
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
#  PHASE 5: Gateway service
# ══════════════════════════════════════════════════════════════════════
phase5_gateway() {
  phase "5" "Setting up gateway service"

  if [[ "$INIT_SYSTEM" == "launchd" || "$INIT_SYSTEM" == "systemd" ]]; then
    # Install as system service (launchd on macOS, systemd on Linux)
    info "Installing gateway service (${INIT_SYSTEM})..."
    openclaw gateway install --force 2>&1 | grep -v "^$" | head -3 || true

    info "Starting gateway..."
    openclaw gateway restart 2>&1 | head -1 || true
  else
    # No service manager — run gateway in foreground mode, backgrounded
    warn "No service manager (systemd/launchd) detected"
    info "Starting gateway in foreground mode..."

    local gw_log="$OPENCLAW_CONFIG_DIR/logs/gateway.log"
    local gw_pidfile="$OPENCLAW_CONFIG_DIR/gateway.pid"
    mkdir -p "$(dirname "$gw_log")"
    # Stop any previously backgrounded gateway
    if [[ -f "$gw_pidfile" ]]; then
      local old_pid
      old_pid=$(cat "$gw_pidfile" 2>/dev/null || echo "")
      if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
      fi
      rm -f "$gw_pidfile"
    fi
    nohup openclaw gateway >> "$gw_log" 2>&1 &
    local gw_pid=$!
    echo "$gw_pid" > "$gw_pidfile"
    ok "Gateway started (PID: ${gw_pid})"
    info "Log: ${gw_log}"
    info "PID file: ${gw_pidfile}"
    warn "Gateway will stop when this shell exits."
    warn "For persistent service, use a process manager (e.g. supervisord, s6) or systemd."
  fi

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
#  PHASE 6: Channel setup
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
    echo -e "  ${CYAN}Feishu App Setup Guide (before install):${NC}"
    echo -e "    1. Go to ${BOLD}https://open.feishu.cn${NC}"
    echo -e "    2. Create an app → get ${YELLOW}App ID${NC} and ${YELLOW}App Secret${NC}"
    echo -e "    3. Enable ${BOLD}bot capability${NC} (Add App Capability > Bot)"
    echo -e "    4. Add permissions (Permissions > API Permissions):"
    echo -e "       ${DIM}im:message:send_as_bot                 Send messages${NC}"
    echo -e "       ${DIM}im:message.p2p_msg:readonly             Receive DMs${NC}"
    echo -e "       ${DIM}im:message.group_at_msg:readonly        Receive @mentions${NC}"
    echo -e "       ${DIM}im:resource                             Images & files${NC}"
    echo -e "       ${DIM}im:chat.access_event.bot_p2p_chat:read  Chat events${NC}"
    echo -e "       ${BOLD}Tip:${NC} Import ${CYAN}feishu-scopes.json${NC} from the install9 repo"
    echo -e "       ${DIM}to add all permissions at once.${NC}"
    echo -e "       ${DIM}Need more? Add scopes as needed (e.g. contact, chat members).${NC}"
    echo ""
    echo -e "  ${CYAN}Steps 5–6 will be done after the installer configures the channel:${NC}"
    echo -e "    5. Events > Use ${BOLD}WebSocket${NC} mode (persistent connection)"
    echo -e "       ${DIM}Requires OpenClaw running first — the installer will start it,${NC}"
    echo -e "       ${DIM}then Feishu can detect the connection.${NC}"
    echo -e "    6. Publish the app version (Version Management > Create Version)"
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
    config_write '
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
    '

    harden_config
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

  # Post-setup reminder: event subscription and publish
  echo ""
  echo -e "  ${YELLOW}${BOLD}Next steps in Feishu console:${NC}"
  echo -e "    1. Go to ${BOLD}Events${NC} > select ${BOLD}WebSocket${NC} (persistent connection)"
  echo -e "       The connection should now be detected — click ${BOLD}Save${NC}"
  echo -e "    2. Go to ${BOLD}Version Management${NC} > ${BOLD}Create Version${NC}"
  echo -e "       Publish the app so permissions take effect"
  echo ""

  # Optional test message
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    if confirm "Send a test message to verify?"; then
      local sessions_file="$OPENCLAW_CONFIG_DIR/agents/main/sessions/sessions.json"
      local open_id=""

      if [[ -f "$sessions_file" ]]; then
        # Extract Open ID from JSON values (quoted strings only, not arbitrary matches)
        open_id=$(grep -Eo '"ou_[a-zA-Z0-9_]{32,}"' "$sessions_file" 2>/dev/null | head -1 | tr -d '"' || echo "")
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

# ── Telegram ──
setup_channel_telegram() {
  local telegram_ext="${OC_ROOT}/extensions/telegram"

  if [[ ! -d "$telegram_ext" ]]; then
    warn "Telegram extension not found at ${telegram_ext}, skipping"
    return
  fi

  # Check existing config
  local existing_token
  existing_token=$(config_read "channels.telegram.botToken")

  local skip_config=false
  if [[ -n "$existing_token" ]]; then
    warn "Telegram already configured"
    if ! confirm "Reconfigure?"; then
      skip_config=true
    fi
  fi

  if [[ "$skip_config" != "true" ]]; then
    echo ""
    echo -e "  ${CYAN}Telegram Bot Setup Guide:${NC}"
    echo -e "    1. Open Telegram, find ${BOLD}@BotFather${NC}"
    echo -e "    2. Send ${BOLD}/newbot${NC} to create a bot"
    echo -e "    3. Copy the ${YELLOW}Bot Token${NC} (e.g. 123456:ABC-DEF...)"
    echo ""

    local bot_token

    if [[ -n "$ARG_TELEGRAM_BOT_TOKEN" ]]; then
      bot_token="$ARG_TELEGRAM_BOT_TOKEN"
    else
      bot_token=$(prompt_secret "Bot Token")
    fi

    if [[ -z "$bot_token" ]]; then
      warn "No Bot Token provided, skipping Telegram setup"
      return
    fi

    # Validate format
    if [[ ! "$bot_token" =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
      warn "Token format may be incorrect (expected: 123456789:ABCdefGHI...)"
    fi

    # Write config
    config_backup
    TG_BOT_TOKEN="$bot_token" \
    config_write '
      if (!config.channels) config.channels = {};
      config.channels.telegram = {
        ...config.channels.telegram,
        enabled: true,
        botToken: process.env.TG_BOT_TOKEN,
        groupPolicy: "open"
      };
      if (!config.plugins) config.plugins = {};
      if (!config.plugins.allow) config.plugins.allow = [];
      if (!config.plugins.allow.includes("telegram")) config.plugins.allow.push("telegram");
      if (!config.plugins.entries) config.plugins.entries = {};
      config.plugins.entries.telegram = { enabled: true };
    '

    harden_config
    ok "Telegram config written"
  fi

  # Restart gateway to load plugin
  info "Restarting gateway to load Telegram plugin..."
  openclaw gateway restart 2>&1 | head -1 || true
  sleep 5

  # Verify
  local status_out
  status_out=$(openclaw status 2>&1 || true)
  if echo "$status_out" | grep -qi "telegram.*OK\|telegram.*online\|telegram.*polling"; then
    ok "Telegram channel: active"
  else
    warn "Telegram may need a moment to connect. Check: openclaw status"
  fi
}

# ── Slack ──
setup_channel_slack() {
  local slack_ext="${OC_ROOT}/extensions/slack"

  if [[ ! -d "$slack_ext" ]]; then
    warn "Slack extension not found at ${slack_ext}, skipping"
    return
  fi

  # Check existing config
  local existing_token
  existing_token=$(config_read "channels.slack.botToken")

  local skip_config=false
  if [[ -n "$existing_token" ]]; then
    warn "Slack already configured"
    if ! confirm "Reconfigure?"; then
      skip_config=true
    fi
  fi

  if [[ "$skip_config" != "true" ]]; then
    echo ""
    echo -e "  ${CYAN}Slack App Setup Guide:${NC}"
    echo -e "    1. Go to ${BOLD}https://api.slack.com/apps${NC}"
    echo -e "    2. Create a new app → ${BOLD}From scratch${NC}"
    echo -e "    3. Enable ${BOLD}Socket Mode${NC} → copy ${YELLOW}App-Level Token${NC} (xapp-...)"
    echo -e "    4. Under ${BOLD}OAuth & Permissions${NC}, add Bot scopes:"
    echo -e "       ${DIM}chat:write, channels:history, groups:history, im:history,${NC}"
    echo -e "       ${DIM}im:read, users:read, reactions:read, files:read${NC}"
    echo -e "    5. Install to workspace → copy ${YELLOW}Bot Token${NC} (xoxb-...)"
    echo -e "    6. Enable ${BOLD}Event Subscriptions${NC} → subscribe to:"
    echo -e "       ${DIM}message.channels, message.groups, message.im, app_mention${NC}"
    echo ""

    local bot_token app_token

    if [[ -n "$ARG_SLACK_BOT_TOKEN" ]]; then
      bot_token="$ARG_SLACK_BOT_TOKEN"
    else
      bot_token=$(prompt_secret "Bot Token (xoxb-...)")
    fi

    if [[ -z "$bot_token" ]]; then
      warn "No Bot Token provided, skipping Slack setup"
      return
    fi

    if [[ ! "$bot_token" =~ ^xoxb- ]]; then
      warn "Bot Token should start with xoxb-"
    fi

    if [[ -n "$ARG_SLACK_APP_TOKEN" ]]; then
      app_token="$ARG_SLACK_APP_TOKEN"
    else
      app_token=$(prompt_secret "App Token (xapp-..., for Socket Mode)")
    fi

    if [[ -z "$app_token" ]]; then
      warn "No App Token provided, skipping Slack setup"
      return
    fi

    if [[ ! "$app_token" =~ ^xapp- ]]; then
      warn "App Token should start with xapp-"
    fi

    # Write config
    config_backup
    SLACK_BOT_TOKEN="$bot_token" \
    SLACK_APP_TOKEN="$app_token" \
    config_write '
      if (!config.channels) config.channels = {};
      config.channels.slack = {
        ...config.channels.slack,
        enabled: true,
        mode: "socket",
        botToken: process.env.SLACK_BOT_TOKEN,
        appToken: process.env.SLACK_APP_TOKEN,
        groupPolicy: "open"
      };
      if (!config.plugins) config.plugins = {};
      if (!config.plugins.allow) config.plugins.allow = [];
      if (!config.plugins.allow.includes("slack")) config.plugins.allow.push("slack");
      if (!config.plugins.entries) config.plugins.entries = {};
      config.plugins.entries.slack = { enabled: true };
    '

    harden_config
    ok "Slack config written"
  fi

  # Restart gateway to load plugin
  info "Restarting gateway to load Slack plugin..."
  openclaw gateway restart 2>&1 | head -1 || true
  sleep 5

  # Verify
  local status_out
  status_out=$(openclaw status 2>&1 || true)
  if echo "$status_out" | grep -qi "slack.*OK\|slack.*online\|slack.*connect"; then
    ok "Slack channel: active"
  else
    warn "Slack may need a moment to connect. Check: openclaw status"
  fi
}

# ── Discord ──
setup_channel_discord() {
  local discord_ext="${OC_ROOT}/extensions/discord"

  if [[ ! -d "$discord_ext" ]]; then
    warn "Discord extension not found at ${discord_ext}, skipping"
    return
  fi

  # Check existing config
  local existing_token
  existing_token=$(config_read "channels.discord.token")

  local skip_config=false
  if [[ -n "$existing_token" ]]; then
    warn "Discord already configured"
    if ! confirm "Reconfigure?"; then
      skip_config=true
    fi
  fi

  if [[ "$skip_config" != "true" ]]; then
    echo ""
    echo -e "  ${CYAN}Discord Bot Setup Guide:${NC}"
    echo -e "    1. Go to ${BOLD}https://discord.com/developers/applications${NC}"
    echo -e "    2. Create a new application"
    echo -e "    3. Go to ${BOLD}Bot${NC} → Reset Token → copy ${YELLOW}Bot Token${NC}"
    echo -e "    4. Enable ${BOLD}Privileged Gateway Intents${NC}:"
    echo -e "       ${DIM}Message Content Intent${NC}"
    echo -e "    5. Go to ${BOLD}OAuth2 → URL Generator${NC}:"
    echo -e "       Scopes: ${DIM}bot${NC}"
    echo -e "       Permissions: ${DIM}Send Messages, Read Message History,${NC}"
    echo -e "       ${DIM}Add Reactions, Attach Files, Use Slash Commands${NC}"
    echo -e "    6. Use the generated URL to invite the bot to your server"
    echo ""

    local bot_token

    if [[ -n "$ARG_DISCORD_BOT_TOKEN" ]]; then
      bot_token="$ARG_DISCORD_BOT_TOKEN"
    else
      bot_token=$(prompt_secret "Bot Token")
    fi

    if [[ -z "$bot_token" ]]; then
      warn "No Bot Token provided, skipping Discord setup"
      return
    fi

    # Write config
    config_backup
    DISCORD_TOKEN="$bot_token" \
    config_write '
      if (!config.channels) config.channels = {};
      config.channels.discord = {
        ...config.channels.discord,
        enabled: true,
        token: process.env.DISCORD_TOKEN,
        groupPolicy: "open"
      };
      if (!config.plugins) config.plugins = {};
      if (!config.plugins.allow) config.plugins.allow = [];
      if (!config.plugins.allow.includes("discord")) config.plugins.allow.push("discord");
      if (!config.plugins.entries) config.plugins.entries = {};
      config.plugins.entries.discord = { enabled: true };
    '

    harden_config
    ok "Discord config written"
  fi

  # Restart gateway to load plugin
  info "Restarting gateway to load Discord plugin..."
  openclaw gateway restart 2>&1 | head -1 || true
  sleep 5

  # Verify
  local status_out
  status_out=$(openclaw status 2>&1 || true)
  if echo "$status_out" | grep -qi "discord.*OK\|discord.*online\|discord.*connect"; then
    ok "Discord channel: active"
  else
    warn "Discord may need a moment to connect. Check: openclaw status"
  fi
}

phase6_channel() {
  phase "6" "Channel setup"

  if [[ "$ARG_SKIP_CHANNEL" == "true" ]]; then
    info "Skipped (--skip-channel)"
    return
  fi

  local channel="$ARG_CHANNEL"
  if [[ -z "$channel" && "$NON_INTERACTIVE" != "true" ]]; then
    echo ""
    echo -e "  Available channels:"
    echo -e "    1) ${BOLD}feishu${NC}    — Feishu / Lark"
    echo -e "    2) ${BOLD}telegram${NC}  — Telegram"
    echo -e "    3) ${BOLD}slack${NC}     — Slack"
    echo -e "    4) ${BOLD}discord${NC}   — Discord"
    echo -e "    s) Skip"
    echo ""
    local choice
    choice=$(prompt "Select channel" "s")
    case "$choice" in
      1|feishu)   channel="feishu" ;;
      2|telegram) channel="telegram" ;;
      3|slack)    channel="slack" ;;
      4|discord)  channel="discord" ;;
      s|S)        channel="skip" ;;
      *)          warn "Unknown choice, skipping"; channel="skip" ;;
    esac
  fi

  case "$channel" in
    feishu|lark) setup_channel_feishu ;;
    telegram)    setup_channel_telegram ;;
    slack)       setup_channel_slack ;;
    discord)     setup_channel_discord ;;
    skip|"")     info "No channel configured" ;;
    *)           warn "Channel '${channel}' is not yet supported" ;;
  esac
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 7: Security hardening & cleanup
# ══════════════════════════════════════════════════════════════════════
phase7_security() {
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
    config_write '
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
    ' 2>/dev/null && { harden_config; ok "denyCommands: cleaned up invalid entries"; fixes=$((fixes + 1)); } || true
  fi

  # ── Set workspaceOnly for filesystem safety ──
  local ws_only
  ws_only=$(config_read "tools.fs.workspaceOnly")
  if [[ "$ws_only" != "true" ]]; then
    config_write '
      if (!config.tools) config.tools = {};
      if (!config.tools.fs) config.tools.fs = {};
      config.tools.fs.workspaceOnly = true;
    ' 2>/dev/null && { harden_config; ok "tools.fs.workspaceOnly: enabled"; fixes=$((fixes + 1)); } || true
  fi

  # ── Disable memory search if no embedding provider ──
  local mem_enabled
  mem_enabled=$(config_read "agents.defaults.memorySearch.enabled")
  if [[ "$mem_enabled" != "false" ]]; then
    if [[ -z "${OPENAI_API_KEY:-}" && -z "${GEMINI_API_KEY:-}" && -z "${VOYAGE_API_KEY:-}" ]]; then
      config_write '
        if (!config.agents) config.agents = {};
        if (!config.agents.defaults) config.agents.defaults = {};
        if (!config.agents.defaults.memorySearch) config.agents.defaults.memorySearch = {};
        config.agents.defaults.memorySearch.enabled = false;
      ' 2>/dev/null && {
        harden_config
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
    local _nullglob_was_set=false
    shopt -q nullglob && _nullglob_was_set=true
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
    if [[ "$_nullglob_was_set" != "true" ]]; then shopt -u nullglob; fi
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

  # ── Harden file permissions ──
  if [[ -d "$OPENCLAW_CONFIG_DIR" ]]; then
    local perms_fixed=false
    local dir_perms
    dir_perms=$(stat -c '%a' "$OPENCLAW_CONFIG_DIR" 2>/dev/null || stat -f '%Lp' "$OPENCLAW_CONFIG_DIR" 2>/dev/null || echo "")
    if [[ -n "$dir_perms" && "$dir_perms" != "700" ]]; then
      chmod 700 "$OPENCLAW_CONFIG_DIR" 2>/dev/null && perms_fixed=true
    fi
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
      local file_perms
      file_perms=$(stat -c '%a' "$OPENCLAW_CONFIG" 2>/dev/null || stat -f '%Lp' "$OPENCLAW_CONFIG" 2>/dev/null || echo "")
      if [[ -n "$file_perms" && "$file_perms" != "600" ]]; then
        chmod 600 "$OPENCLAW_CONFIG" 2>/dev/null && perms_fixed=true
      fi
    fi
    if [[ "$perms_fixed" == "true" ]]; then
      ok "File permissions: hardened (~/.openclaw 700, config 600)"
      fixes=$((fixes + 1))
    fi
  fi

  # ── Verify gateway.auth.mode is "token" ──
  local auth_mode
  auth_mode=$(config_read "gateway.auth.mode")
  if [[ -n "$auth_mode" && "$auth_mode" != "token" ]]; then
    config_write '
      if (!config.gateway) config.gateway = {};
      if (!config.gateway.auth) config.gateway.auth = {};
      config.gateway.auth.mode = "token";
    ' 2>/dev/null && {
      harden_config
      ok "gateway.auth.mode: set to token (was: ${auth_mode})"
      fixes=$((fixes + 1))
    } || true
  fi

  # ── Verify gateway listens on localhost only ──
  local gw_host
  gw_host=$(config_read "gateway.host")
  if [[ -n "$gw_host" && "$gw_host" != "127.0.0.1" && "$gw_host" != "localhost" ]]; then
    warn "gateway.host is '${gw_host}' — consider restricting to 127.0.0.1"
  fi

  # ── Harden permissions on backup files ──
  # shellcheck disable=SC2012
  for bak_file in $(ls -1 "${OPENCLAW_CONFIG}".bak.* 2>/dev/null); do
    chmod 600 "$bak_file" 2>/dev/null || true
  done

  if [[ $fixes -eq 0 ]]; then
    ok "No issues found"
  else
    ok "${fixes} issue(s) fixed"
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  PHASE 8: Summary
# ══════════════════════════════════════════════════════════════════════
phase8_summary() {
  phase "8" "Setup complete"

  local oc_version
  oc_version=$(openclaw --version 2>/dev/null || echo "unknown")

  # Detect active channels
  local channels=""
  for ch in feishu telegram slack discord; do
    local ch_enabled
    ch_enabled=$(config_read "channels.${ch}.enabled")
    if [[ "$ch_enabled" == "true" ]]; then
      channels="${channels}${ch} "
    fi
  done

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
    # Show example for the first configured channel
    local first_ch
    first_ch=$(echo "$channels" | awk '{print $1}')
    echo -e "    ${CYAN}openclaw message send --channel ${first_ch} \\${NC}"
    echo -e "    ${CYAN}  --target <id> --message \"hello\"${NC}"
    echo ""
  fi

  divider
  echo -e "  ${BOLD}Documentation:${NC}  https://docs.openclaw.ai"
  echo ""

  if [[ "$NEED_TOKEN_FIX" == "true" ]]; then
    echo -e "  ${YELLOW}${BOLD}Important:${NC} Run ${CYAN}source ~/${SHELL_RC##*/}${NC} or open a new terminal"
    echo -e "  to activate the gateway token in your shell."
    echo ""
  fi

  # Dashboard URL — always display prominently
  local dashboard_url="http://127.0.0.1:${gw_port}/"
  divider
  echo ""
  echo -e "  ${GREEN}${BOLD}▶ Dashboard:${NC}  ${CYAN}${BOLD}${dashboard_url}${NC}"
  echo ""

  # Auto-open in browser (interactive mode only)
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    if [[ "$OS" == "darwin" ]]; then
      open "$dashboard_url" 2>/dev/null && ok "Dashboard opened in browser" || true
    elif command -v xdg-open &>/dev/null; then
      xdg-open "$dashboard_url" 2>/dev/null && ok "Dashboard opened in browser" || true
    elif command -v wslview &>/dev/null; then
      wslview "$dashboard_url" 2>/dev/null && ok "Dashboard opened in browser" || true
    fi
  fi
}

# ══════════════════════════════════════════════════════════════════════
#  Uninstall
# ══════════════════════════════════════════════════════════════════════
do_uninstall() {
  banner
  detect_platform

  echo -e "  ${RED}${BOLD}OpenClaw Uninstaller${NC}"
  echo ""

  # ── 1. Stop gateway ──
  info "Stopping gateway..."
  if [[ "$INIT_SYSTEM" == "launchd" ]]; then
    openclaw gateway stop 2>/dev/null || true
    openclaw gateway uninstall 2>/dev/null || true
    ok "launchd service removed"
  elif [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl --user stop openclaw-gateway.service 2>/dev/null || true
    systemctl --user disable openclaw-gateway.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/openclaw-gateway.service" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    ok "systemd service removed"
  else
    # Stop via pidfile first, then fall back to pkill with full command match
    local gw_pidfile="$OPENCLAW_CONFIG_DIR/gateway.pid"
    if [[ -f "$gw_pidfile" ]]; then
      local old_pid
      old_pid=$(cat "$gw_pidfile" 2>/dev/null || echo "")
      if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
      fi
      rm -f "$gw_pidfile"
    fi
    pkill -xf "node.*openclaw-gateway" 2>/dev/null || true
    pkill -xf "node.*openclaw gateway" 2>/dev/null || true
    ok "Gateway processes stopped"
  fi

  # ── 2. Uninstall npm package ──
  if command -v openclaw &>/dev/null; then
    local oc_ver
    oc_ver=$(openclaw --version 2>/dev/null || echo "unknown")
    info "Uninstalling openclaw (${oc_ver})..."
    npm uninstall -g openclaw 2>&1 | tail -1 || true
    if ! command -v openclaw &>/dev/null; then
      ok "openclaw npm package removed"
    else
      warn "npm uninstall may have failed, try manually: npm uninstall -g openclaw"
    fi
  else
    ok "openclaw not installed (skipped)"
  fi

  # ── 3. Config & data ──
  if [[ -d "$OPENCLAW_CONFIG_DIR" ]]; then
    echo ""
    echo -e "  ${BOLD}Config directory:${NC} ${OPENCLAW_CONFIG_DIR}"
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
      local channels_configured=""
      for ch in feishu telegram slack discord; do
        local ch_val
        ch_val=$(OC_KEY="channels.${ch}.enabled" OC_FILE="$OPENCLAW_CONFIG" node -e '
          try {
            const c = JSON.parse(require("fs").readFileSync(process.env.OC_FILE, "utf8"));
            const keys = process.env.OC_KEY.split(".");
            let v = c; for (const k of keys) v = v?.[k];
            console.log(String(v ?? ""));
          } catch { console.log(""); }
        ' 2>/dev/null || echo "")
        if [[ "$ch_val" == "true" ]]; then
          channels_configured="${channels_configured}${ch} "
        fi
      done
      if [[ -n "$channels_configured" ]]; then
        warn "Active channels found: ${channels_configured}"
      fi
    fi
    echo ""

    if confirm "Delete config directory (~/.openclaw)?"; then
      # Backup before deletion
      local backup_tar
      backup_tar="${HOME}/openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
      info "Creating backup: ${backup_tar}"
      if tar -czf "$backup_tar" -C "$HOME" .openclaw 2>/dev/null; then
        ok "Backup saved: ${backup_tar}"
      else
        warn "Backup failed, proceeding anyway"
      fi

      rm -rf "$OPENCLAW_CONFIG_DIR"
      ok "Config directory deleted"
    else
      info "Config directory kept: ${OPENCLAW_CONFIG_DIR}"
    fi
  fi

  # ── 4. Shell RC cleanup ──
  info "Cleaning shell RC files..."
  local cleaned=false
  for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.cshrc" "$HOME/.config/fish/config.fish"; do
    if [[ -f "$rc_file" ]] && grep -q "OPENCLAW_GATEWAY_TOKEN" "$rc_file" 2>/dev/null; then
      # Remove the token line and the comment above it
      if [[ "$OS" == "darwin" ]]; then
        sed -i '' '/# OpenClaw Gateway Token/d' "$rc_file"
        sed -i '' '/OPENCLAW_GATEWAY_TOKEN/d' "$rc_file"
      else
        sed -i '/# OpenClaw Gateway Token/d' "$rc_file"
        sed -i '/OPENCLAW_GATEWAY_TOKEN/d' "$rc_file"
      fi
      ok "Cleaned: ${rc_file}"
      cleaned=true
    fi
  done
  if [[ "$cleaned" != "true" ]]; then
    ok "No token entries found in shell RC files"
  fi

  # ── 5. Remove install9 command ──
  if [[ -f "$INSTALL9_BIN" ]]; then
    rm -f "$INSTALL9_BIN"
    ok "Removed: ${INSTALL9_BIN}"
  fi
  # Clean install9 PATH entries from shell RCs (match exact install9 lines only)
  for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    if [[ -f "$rc_file" ]] && grep -q "# install9 command" "$rc_file" 2>/dev/null; then
      sed_inplace '/# install9 command/d' "$rc_file"
      # Only remove .local/bin PATH lines added by install9 (match the exact export pattern)
      sed_inplace '/export PATH=.*\.local\/bin.*\$PATH/d' "$rc_file"
      sed_inplace '/fish_add_path.*\.local\/bin/d' "$rc_file"
      ok "Cleaned install9 PATH from: ${rc_file}"
    fi
  done

  # ── 6. Temp files ──
  if [[ -d "/tmp/openclaw" ]]; then
    rm -rf "/tmp/openclaw"
    ok "Cleaned /tmp/openclaw"
  fi

  # ── Done ──
  echo ""
  divider
  echo -e "  ${GREEN}${BOLD}Uninstall complete.${NC}"
  echo ""
  if [[ -d "${NVM_DIR:-$HOME/.nvm}" ]]; then
    info "nvm and Node.js were kept (shared dependency)."
    info "To remove nvm: rm -rf ~/.nvm && remove nvm lines from your shell RC"
  fi
  echo ""
}

# ══════════════════════════════════════════════════════════════════════
#  Self-install: register as local command
# ══════════════════════════════════════════════════════════════════════
self_install() {
  local bin_dir
  bin_dir="$(dirname "$INSTALL9_BIN")"

  # Determine the source: running script itself
  local script_source=""
  if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    script_source="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  fi

  # Skip if already installed and up to date
  if [[ -f "$INSTALL9_BIN" ]]; then
    if [[ -n "$script_source" && "$script_source" -ef "$INSTALL9_BIN" ]]; then
      return  # Already running from installed location
    fi
    # Check if installed version matches
    local installed_ver
    installed_ver=$(grep '^INSTALLER_VERSION=' "$INSTALL9_BIN" 2>/dev/null | head -1 | cut -d'"' -f2)
    if [[ "$installed_ver" == "$INSTALLER_VERSION" ]]; then
      return  # Same version already installed
    fi
  fi

  mkdir -p "$bin_dir"

  if [[ -n "$script_source" && -f "$script_source" ]]; then
    cp "$script_source" "$INSTALL9_BIN"
  else
    # Piped via curl — download a clean copy
    curl -fsSL --connect-timeout 15 --max-time 60 "$INSTALL9_URL" -o "$INSTALL9_BIN"
  fi
  chmod +x "$INSTALL9_BIN"

  # Ensure ~/.local/bin is in PATH
  if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    local path_line=""
    if [[ "$SHELL_TYPE" == "fish" ]]; then
      path_line="fish_add_path $bin_dir"
    else
      path_line="export PATH=\"$bin_dir:\$PATH\""
    fi

    if ! grep -q "$bin_dir" "$SHELL_RC" 2>/dev/null; then
      { echo ""; echo "# install9 command"; echo "$path_line"; } >> "$SHELL_RC"
    fi
    export PATH="$bin_dir:$PATH"
  fi

  ok "install9 command installed: ${INSTALL9_BIN}"
  info "Run ${BOLD}install9 --help${NC} from any terminal"
}

do_self_update() {
  banner
  info "Updating install9..."

  local tmp_script
  tmp_script=$(mktemp)

  if curl -fsSL --connect-timeout 15 --max-time 60 "$INSTALL9_URL" -o "$tmp_script"; then
    local remote_ver
    remote_ver=$(grep '^INSTALLER_VERSION=' "$tmp_script" 2>/dev/null | head -1 | cut -d'"' -f2)

    if [[ -z "$remote_ver" ]]; then
      rm -f "$tmp_script"
      fail "Downloaded file does not look like a valid installer"
    fi

    # Basic content validation
    local file_size
    file_size=$(wc -c < "$tmp_script" | tr -d ' ')
    if [[ "$file_size" -lt 1000 ]] || ! grep -q "phase1_detect" "$tmp_script" || ! grep -q "^main()" "$tmp_script"; then
      rm -f "$tmp_script"
      fail "Downloaded file failed integrity check"
    fi

    if [[ "$remote_ver" == "$INSTALLER_VERSION" ]]; then
      rm -f "$tmp_script"
      ok "Already on latest version ($INSTALLER_VERSION)"
      exit 0
    fi

    local bin_dir
    bin_dir="$(dirname "$INSTALL9_BIN")"
    mkdir -p "$bin_dir"
    mv "$tmp_script" "$INSTALL9_BIN"
    chmod +x "$INSTALL9_BIN"
    ok "Updated: v${INSTALLER_VERSION} → v${remote_ver}"
    info "Run ${BOLD}install9 --version${NC} to verify"
  else
    rm -f "$tmp_script"
    fail "Failed to download update from ${INSTALL9_URL}"
  fi
  exit 0
}

# ══════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════
main() {
  parse_args "$@"

  if [[ "$ARG_UNINSTALL" == "true" ]]; then
    do_uninstall
    exit 0
  fi

  if [[ "$ARG_SELF_UPDATE" == "true" ]]; then
    do_self_update
  fi

  banner
  phase1_detect
  phase2_deps
  phase3_install
  phase4_init
  phase5_gateway
  phase6_channel
  phase7_security
  self_install
  phase8_summary
}

main "$@"
