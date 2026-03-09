# install9

One-click installer and initializer for [OpenClaw](https://github.com/OpenClaw) — the multi-channel AI agent platform.

```sh
curl -fsSL https://install9.ai/openclaw | bash
```

## What it does

install9 is a single shell script that takes a fresh machine from zero to a fully configured OpenClaw instance:

1. **Environment detection** — Identifies OS (macOS / Linux), architecture, package manager (brew, apt, dnf, pacman, apk), and shell type
2. **Dependency installation** — Installs Node.js via nvm with automatic PATH configuration
3. **OpenClaw installation** — Installs or upgrades OpenClaw via npm
4. **Configuration initialization** — Creates `~/.openclaw/openclaw.json` with sensible defaults
5. **Gateway service setup** — Configures launchd (macOS), systemd (Linux), or foreground mode (Docker / containers) with secure token management
6. **Channel integration** — Interactive guided setup for Feishu/Lark, Telegram, Slack, Discord
7. **Security hardening** — File system isolation, command deny-lists, memory search controls
8. **Dashboard** — Automatically opens the OpenClaw Dashboard in browser on completion

## Usage

### Quick install (interactive)

```sh
curl -fsSL https://install9.ai/openclaw | bash
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

### Uninstall

```sh
curl -fsSL https://install9.ai/openclaw | bash -s -- --uninstall
```

Or if you have the script locally:

```sh
bash install.sh --uninstall
```

Non-interactive uninstall (no confirmation prompts):

```sh
bash install.sh --non-interactive --uninstall
```

The uninstaller will:

- Stop and remove the gateway service (launchd / systemd / background process)
- Uninstall the `openclaw` npm package
- Back up `~/.openclaw/` to `~/openclaw-backup-*.tar.gz`, then delete it
- Remove `OPENCLAW_GATEWAY_TOKEN` from shell RC files (`.bashrc`, `.zshrc`, `config.fish`)
- Clean up temporary files (`/tmp/openclaw`)
- Keep nvm and Node.js (shared dependencies)

### CLI flags

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

| OS | Architectures | Package managers |
|----|---------------|-----------------|
| macOS | arm64, x86_64 | Homebrew |
| Linux | amd64, arm64 | apt, dnf, yum, pacman, apk |
| Docker | arm64, amd64 | (auto-detected, gateway runs in foreground mode) |

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
├── install.sh                  # The installer script
├── LICENSE                     # Apache-2.0
└── README.md
```

The website [install9.ai](https://install9.ai) is deployed separately. It proxies `install9.ai/openclaw` to this repo's `install.sh` via GitHub raw URL.

## Development

### Testing the installer

Dry-run in a container:

```sh
docker run --rm -it ubuntu:22.04 bash -c \
  "apt-get update && apt-get install -y curl && bash <(curl -fsSL https://install9.ai/openclaw)"
```

Or run locally:

```sh
bash install.sh --help
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
