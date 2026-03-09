# install.sh 交互式安装 UI 流程

```mermaid
graph TD
    Start["curl -fsSL https://install9.ai/openclaw | bash"] --> Banner

    Banner["╔══════════════════════════════════════════╗
    ║  OpenClaw — Installer v1.1.0             ║
    ╚══════════════════════════════════════════╝"]

    Banner --> P1

    P1["<b>[1/8] Detecting environment</b>
    ▸ OS: darwin (arm64)
    ▸ Package manager: brew
    ▸ Shell: zsh → ~/.zshrc
    ▸ Init system: launchd
    ▸ OpenClaw not found — will install"]

    P1 --> P2

    P2["<b>[2/8] Checking dependencies</b>
    ✔ git: git version 2.x.x
    ✔ curl: available
    ✔ openssl: available
    ✔ jq: available"]

    P2 --> NodeCheck{Node.js ≥ 22?}

    NodeCheck -->|"✔ 已安装"| P3
    NodeCheck -->|"✖ 未安装"| NodePrompt

    NodePrompt["▸ Node.js 22+ is required. Choose install method:
      1) <b>nvm</b> (recommended, user-space)
      2) <b>System package manager</b> (brew)

    <b>Select [1/2]</b> [1]: <i>用户输入 1 或 2</i>"]

    NodePrompt -->|"1 → nvm"| NvmInstall["▸ Installing nvm first...
    ▸ Installing Node.js 22 via nvm...
    ✔ Node.js installed: v22.x.x"]
    NodePrompt -->|"2 → 包管理器"| PkgInstall["▸ Installing node@22 via brew...
    ✔ Node.js installed: v22.x.x"]

    NvmInstall --> P3
    PkgInstall --> P3

    P3["<b>[3/8] Installing OpenClaw</b>"]
    P3 --> OcExists{OpenClaw 已安装?}

    OcExists -->|"否"| OcInstall["▸ Installing openclaw globally via npm...
    ✔ OpenClaw 2026.x.x installed"]
    OcExists -->|"是"| OcUpgrade

    OcUpgrade["✔ OpenClaw 2026.x.x already installed
    <b>Check for updates?</b> [Y/n]: <i>用户输入</i>"]

    OcUpgrade -->|Y| OcUpgradeCheck["▸ Checking latest version...
    ✔ Already on latest version"]
    OcUpgrade -->|n| P4

    OcUpgradeCheck --> P4
    OcInstall --> P4

    P4["<b>[4/8] Initializing configuration</b>
    ▸ No config found. Running initial setup...
    ✔ Minimal config created"]

    P4 --> ModelSetup

    ModelSetup["<b>Model provider</b>:
      1) anthropic    2) openai       3) openai-codex
      4) google       5) openrouter   6) xai
      7) mistral      8) groq         9) minimax
      10) zai         11) ollama      12) openai-compatible
      s) Skip

    <b>Select provider</b> [1]: <i>用户输入</i>"]

    ModelSetup --> ModelName["ℹ Other models: claude-opus-4-6, claude-haiku-4-5
    <b>Model name</b> [claude-sonnet-4-6]: <i>用户输入或回车</i>"]

    ModelName --> ApiKey["<b>ANTHROPIC_API_KEY</b>: <i>********（星号掩码）</i>
    ✔ API key written to ~/.zshrc
    ✔ API key written to ~/.openclaw/.env"]

    ApiKey --> GatewayToken["▸ Generating new gateway token...
    ✔ Gateway token: set
    ✔ Token written to ~/.zshrc"]

    GatewayToken --> P5

    P5["<b>[5/8] Setting up gateway service</b>
    ▸ Installing gateway service...
    ▸ Starting gateway...
    ▸ Verifying gateway connection...
    ✔ Gateway: running and connected"]

    P5 --> P6

    P6["<b>[6/8] Channel setup</b>

    Available channels:
      1) <b>feishu</b>   — Feishu / Lark
      2) <b>telegram</b> — Telegram
      3) <b>slack</b>    — Slack
      4) <b>discord</b>  — Discord
      s) Skip

    <b>Select channel</b> [1]: <i>用户输入</i>"]

    P6 -->|"s → 跳过"| P7
    P6 -->|"1 → feishu"| FeishuSetup

    FeishuSetup["飞书应用配置指南:
      1. 前往 <b>https://open.feishu.cn</b>
      2. 创建应用 → 获取 App ID 和 App Secret
      3. 添加应用能力 → <b>机器人</b>"]

    FeishuSetup --> FeishuInput

    FeishuInput["<b>App ID</b>: <i>用户输入 cli_xxxxxxxxxxxxxxxx</i>
    <b>App Secret</b>: <i>********（星号掩码）</i>"]

    FeishuInput --> FeishuDomain

    FeishuDomain["  1) <b>feishu</b> — 中国大陆
      2) <b>lark</b>   — 国际版

    <b>Select [1/2]</b> [1]: <i>用户输入</i>"]

    FeishuDomain --> FeishuSave["✔ Feishu config written
    ▸ Restarting gateway to load Feishu plugin...
    ✔ Feishu channel: active"]

    FeishuSave --> FeishuNextSteps

    FeishuNextSteps["Next steps in Feishu console:
      1. <b>权限管理</b> — 添加权限:
         • im:message.receive_v1（接收消息）
         • contact:contact.base:readonly（解析发送者）
      2. <b>事件与回调 > 事件配置</b> — 添加事件:
         • im.message.receive_v1（接收消息）
      3. <b>事件与回调 > 回调配置</b> — 选择 <b>WebSocket</b>
      4. <b>版本管理</b> > 创建版本 > 发布"]

    FeishuNextSteps --> FeishuTest

    FeishuTest["<b>Send a test message to verify?</b> [Y/n]: <i>用户输入</i>"]

    FeishuTest -->|n| P7
    FeishuTest -->|Y| FeishuPairing

    FeishuPairing{检测到 Pairing?}

    FeishuPairing -->|"是"| FeishuAutoApprove["ℹ Auto-approving pairing code: AQ26XKCJ
    ✔ Pairing approved. Send another message to your bot in Feishu now.
    <b>Press Enter to retry, or 's' to skip</b>: <i>用户按回车</i>"]
    FeishuPairing -->|"否"| FeishuOpenId

    FeishuAutoApprove --> FeishuOpenId

    FeishuOpenId["ℹ Detected Open ID: ou_xxxxxxxx
    <b>Confirm Open ID</b> [ou_xxx]: <i>用户确认或输入</i>"]

    FeishuOpenId --> FeishuTestResult["✔ Test message sent! Check Feishu."]

    FeishuTestResult --> P7

    P7["<b>[7/8] Security hardening & cleanup</b>
    ✔ denyCommands: cleaned up invalid entries
    ✔ tools.fs.workspaceOnly: enabled
    ✔ memorySearch: disabled (no embedding provider)
    ✔ 3 issue(s) fixed"]

    P7 --> P8

    P8["<b>[8/8] Setup complete</b>

    ╔══════════════════════════════════════════╗
    ║  OpenClaw is ready!                      ║
    ╚══════════════════════════════════════════╝

    Version:   2026.x.x
    Config:    ~/.openclaw/openclaw.json
    Channels:  feishu
    Gateway:   ws://127.0.0.1:18789

    Quick start:
      openclaw status         # Health check
      openclaw logs --follow  # Live logs
      openclaw tui            # Terminal chat UI

    ▶ Dashboard:  http://127.0.0.1:18789/#token=xxx...
    ✔ Dashboard opened in browser"]

    style Banner fill:#1a1a2e,color:#00d4ff,stroke:#00d4ff
    style P8 fill:#0d3b0d,color:#4eff4e,stroke:#4eff4e
    style NodePrompt fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style ModelSetup fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style ModelName fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style ApiKey fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style FeishuInput fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style FeishuDomain fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style FeishuTest fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style FeishuOpenId fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style FeishuAutoApprove fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style OcUpgrade fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style OcUpgradeCheck fill:#2d2d00,color:#ffff66,stroke:#ffff66
    style P6 fill:#2d2d00,color:#ffff66,stroke:#ffff66
```
