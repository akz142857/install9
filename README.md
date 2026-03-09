# install9

One-click installer and initializer for [OpenClaw](https://github.com/OpenClaw) — the multi-channel AI agent platform.

**macOS / Linux:**

```sh
curl -fsSL https://install9.ai/openclaw | bash
```

**Windows (PowerShell):**

```powershell
irm https://install9.ai/openclaw-win | iex
```

## What it does

install9 takes a fresh machine from zero to a fully configured OpenClaw instance:

1. **Environment detection** — Identifies OS (macOS / Linux / Windows), architecture, package manager, and shell type
2. **Dependency installation** — Installs Node.js via nvm (macOS/Linux) or fnm (Windows) with automatic PATH configuration
3. **OpenClaw installation** — Installs or upgrades OpenClaw via npm
4. **Configuration initialization** — Creates `~/.openclaw/openclaw.json` with sensible defaults
5. **Gateway service setup** — Configures launchd (macOS), systemd (Linux), Scheduled Task (Windows), or foreground mode (Docker / containers) with secure token management
6. **Channel integration** — Interactive guided setup for Feishu/Lark, Telegram, Slack, Discord
7. **Security hardening** — File system isolation, command deny-lists, memory search controls
8. **Dashboard** — Automatically opens the OpenClaw Dashboard in browser on completion

## Usage

### Quick install (interactive)

macOS / Linux:

```sh
curl -fsSL https://install9.ai/openclaw | bash
```

Windows (PowerShell):

```powershell
irm https://install9.ai/openclaw-win | iex
```

### Passing arguments on Windows

Since `irm | iex` does not support inline arguments, set the environment variable first:

```powershell
$env:OPENCLAW_INSTALL_ARGS='--channel feishu'; irm https://install9.ai/openclaw-win | iex
```

Or run the script directly (requires `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`):

```powershell
.\install.ps1 --channel feishu --feishu-app-id cli_xxx --feishu-app-secret xxx
```

### Non-interactive examples

Feishu / Lark:

```sh
curl -fsSL https://install9.ai/openclaw | bash -s -- \
  --non-interactive \
  --channel feishu \
  --feishu-app-id cli_xxx \
  --feishu-app-secret xxx
```

Telegram:

```sh
curl -fsSL https://install9.ai/openclaw | bash -s -- \
  --non-interactive \
  --channel telegram \
  --telegram-token "123456789:ABCdefGHI..."
```

Slack:

```sh
curl -fsSL https://install9.ai/openclaw | bash -s -- \
  --non-interactive \
  --channel slack \
  --slack-bot-token "xoxb-..." \
  --slack-app-token "xapp-..."
```

Discord:

```sh
curl -fsSL https://install9.ai/openclaw | bash -s -- \
  --non-interactive \
  --channel discord \
  --discord-token "your-bot-token"
```

### Self-update

After the first install, `install9` is registered as a local command. To update it:

```sh
install9 --self-update
```

### Uninstall

macOS / Linux:

```sh
curl -fsSL https://install9.ai/openclaw | bash -s -- --uninstall
```

Windows (PowerShell):

```powershell
$env:OPENCLAW_INSTALL_ARGS='--uninstall'; irm https://install9.ai/openclaw-win | iex
```

Or if you have the script locally:

```sh
bash install.sh --uninstall
```

```powershell
.\install.ps1 --uninstall
```

Non-interactive uninstall (no confirmation prompts):

```sh
bash install.sh --non-interactive --uninstall
```

The uninstaller will:

- Stop and remove the gateway service (launchd / systemd / Scheduled Task / background process)
- Uninstall the `openclaw` npm package
- Back up `~/.openclaw/` to `~/openclaw-backup-*.tar.gz` (or `.zip` on Windows), then delete it
- Remove `OPENCLAW_GATEWAY_TOKEN` from shell RC files (`.bashrc`, `.zshrc`, `config.fish`) or PowerShell profile and user environment variables
- Remove the `install9` command and its PATH entries
- Clean up temporary files (`/tmp/openclaw` or `$env:TEMP\openclaw`)
- Keep nvm/fnm and Node.js (shared dependencies)

### CLI flags

Both `install.sh` and `install.ps1` accept the same flags:

| Flag | Description |
|------|-------------|
| `--non-interactive` | Skip all prompts, use defaults |
| `--channel NAME` | Channel to configure (`feishu`, `lark`, `telegram`, `slack`, `discord`) |
| `--feishu-app-id ID` | Feishu App ID |
| `--feishu-app-secret SECRET` | Feishu App Secret |
| `--feishu-domain DOMAIN` | `feishu` (default) or `lark` |
| `--telegram-token TOKEN` | Telegram Bot Token (from @BotFather) |
| `--slack-bot-token TOKEN` | Slack Bot Token (`xoxb-...`) |
| `--slack-app-token TOKEN` | Slack App Token (`xapp-...`, for Socket Mode) |
| `--discord-token TOKEN` | Discord Bot Token |
| `--uninstall` | Uninstall OpenClaw and clean up |
| `--self-update` | Update the install9 command itself |
| `--skip-channel` | Skip channel setup phase |
| `--skip-security` | Skip security hardening phase |
| `--skip-deps` | Skip dependency installation |
| `-h, --help` | Show help message |
| `-v, --version` | Show installer version |

## Supported channels

| Channel | Status | Credentials needed |
|---------|--------|--------------------|
| Feishu / Lark | Supported | App ID + App Secret |
| Telegram | Supported | Bot Token (from @BotFather) |
| Slack | Supported | Bot Token (`xoxb-`) + App Token (`xapp-`, Socket Mode) |
| Discord | Supported | Bot Token |

## Supported platforms

| OS | Architectures | Package managers | Service manager |
|----|---------------|-----------------|-----------------|
| macOS | arm64, x86_64 | Homebrew | launchd |
| Linux | amd64, arm64 | apt, dnf, yum, pacman, apk | systemd |
| Windows | x64, arm64 | winget, choco, scoop | Scheduled Task |
| Docker | arm64, amd64 | (auto-detected) | foreground mode |

### Platform-specific details

| | macOS / Linux (`install.sh`) | Windows (`install.ps1`) |
|---|---|---|
| Shell | Bash (POSIX-compatible) | PowerShell 5.1+ |
| Node.js manager | nvm | fnm |
| Interactive input | `/dev/tty` | `[Console]::ReadLine()` |
| Token storage | Shell RC file (`export`) | PowerShell profile + user env var |
| Crypto | `openssl rand` | `.NET RandomNumberGenerator` |
| JSON parsing | `jq` / `node` | `ConvertFrom-Json` / `node` |

## Installation UI flow

Interactive installation step-by-step guide:

- [中文版](docs/install-ui-flow-zh.md)
- [English](docs/install-ui-flow-en.md)

## Project structure

```
.
├── docs/
│   ├── install-ui-flow-zh.md   # Installation UI flow (Chinese)
│   └── install-ui-flow-en.md   # Installation UI flow (English)
├── install.sh                  # Installer for macOS / Linux
├── install.ps1                 # Installer for Windows
├── LICENSE                     # Apache-2.0
└── README.md
```

The website [install9.ai](https://install9.ai) is deployed separately. It proxies:

- `install9.ai/openclaw` → `install.sh` (via GitHub raw URL, 200 proxy)
- `install9.ai/openclaw-win` → `install.ps1` (via GitHub raw URL, 200 proxy)

## Development

### Testing the installer

macOS / Linux — dry-run in a container:

```sh
docker run --rm -it ubuntu:22.04 bash -c \
  "apt-get update && apt-get install -y curl && bash <(curl -fsSL https://install9.ai/openclaw)"
```

Or run locally:

```sh
bash install.sh --help
```

Windows — run locally:

```powershell
pwsh install.ps1 --help
```

Or with Bypass policy:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 --help
```

### Testing uninstall

```sh
docker run --rm -it ubuntu:22.04 bash -c \
  "apt-get update && apt-get install -y curl && \
   bash <(curl -fsSL https://install9.ai/openclaw) --non-interactive --skip-channel && \
   bash <(curl -fsSL https://install9.ai/openclaw) --non-interactive --uninstall"
```

### Linting

```sh
shellcheck install.sh
```

## Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Run `shellcheck install.sh` to lint
5. Submit a pull request

## License

[Apache-2.0](LICENSE)
