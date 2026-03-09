# install9

One-click installer and initializer for [OpenClaw](https://github.com/akz142857/install9) — the multi-channel AI agent platform.

```sh
curl -fsSL install9.ai/openclaw | bash
```

## What it does

install9 is a single shell script that takes a fresh machine from zero to a fully configured OpenClaw instance:

1. **Environment detection** — Identifies OS (macOS / Linux), architecture, package manager (brew, apt, dnf, pacman, apk), and shell type
2. **Dependency installation** — Installs Node.js via nvm with automatic PATH configuration
3. **OpenClaw installation** — Installs or upgrades OpenClaw via npm
4. **Configuration initialization** — Creates `~/.openclaw/openclaw.json` with sensible defaults
5. **Gateway service setup** — Configures launchd (macOS) or systemd (Linux) with secure token management
6. **Channel integration** — Interactive guided setup for Feishu/Lark (more channels coming)
7. **Security hardening** — File system isolation, command deny-lists, memory search controls

## Usage

### Quick install (interactive)

```sh
curl -fsSL install9.ai/openclaw | bash
```

### Non-interactive

```sh
curl -fsSL install9.ai/openclaw | bash -s -- \
  --non-interactive \
  --channel feishu \
  --feishu-app-id cli_xxx \
  --feishu-app-secret xxx
```

### CLI flags

| Flag | Description |
|------|-------------|
| `--non-interactive` | Skip all prompts, use defaults |
| `--channel feishu` | Auto-configure Feishu channel |
| `--feishu-app-id ID` | Feishu App ID |
| `--feishu-app-secret SECRET` | Feishu App Secret |
| `--feishu-domain feishu\|lark` | Feishu or Lark domain (default: `feishu`) |
| `--skip-security` | Skip security hardening phase |
| `--skip-channel` | Skip channel setup phase |
| `--skip-deps` | Skip dependency installation |
| `--help` | Show help message |

## Supported platforms

| OS | Architectures | Package managers |
|----|---------------|-----------------|
| macOS | arm64, x86_64 | Homebrew |
| Linux | amd64, arm64 | apt, dnf, yum, pacman, apk |

## Project structure

```
.
├── .github/workflows/ci.yml   # ShellCheck CI
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
  "apt-get update && apt-get install -y curl && bash <(curl -fsSL install9.ai/openclaw)"
```

Or run locally:

```sh
bash install.sh --help
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
