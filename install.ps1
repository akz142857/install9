#Requires -Version 5.1
# ======================================================================
#  OpenClaw - One-line installer & initializer (Windows)
#  Usage:
#    irm https://install9.ai/openclaw-win | iex
#    .\install.ps1 --help
#
#  For arguments via one-liner, set env first:
#    $env:OPENCLAW_INSTALL_ARGS='--channel feishu'; irm https://install9.ai/openclaw-win | iex
#
#  Direct execution requires: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#  Or run with: powershell -ExecutionPolicy Bypass -File .\install.ps1
#
#  Version: 1.0.0
#  License: Apache-2.0
#  Compat:  Windows 10/11 (x64/arm64)
# ======================================================================

$ErrorActionPreference = 'Stop'

$INSTALLER_VERSION = "1.0.0"
$MIN_NODE_MAJOR = 22
$OPENCLAW_PKG = "openclaw"
$OPENCLAW_CONFIG_DIR = Join-Path $env:USERPROFILE ".openclaw"
$OPENCLAW_CONFIG = Join-Path $OPENCLAW_CONFIG_DIR "openclaw.json"
$TOTAL_PHASES = 8
$INSTALL9_DIR = Join-Path $env:LOCALAPPDATA "install9"
$INSTALL9_BIN = Join-Path $INSTALL9_DIR "install9.ps1"
$INSTALL9_CMD = Join-Path $INSTALL9_DIR "install9.cmd"
$INSTALL9_URL = "https://install9.ai/openclaw-win"

# -- CLI arguments -----------------------------------------------------
$script:NonInteractive = $false
$script:ArgChannel = ""
$script:ArgFeishuAppId = ""
$script:ArgFeishuAppSecret = ""
$script:ArgFeishuDomain = "feishu"
$script:ArgTelegramToken = ""
$script:ArgSlackBotToken = ""
$script:ArgSlackAppToken = ""
$script:ArgDiscordToken = ""
$script:ArgUninstall = $false
$script:ArgSelfUpdate = $false
$script:ArgSkipSecurity = $false
$script:ArgSkipChannel = $false
$script:ArgSkipDeps = $false
$script:ArgSkipModel = $false
$script:NeedTokenFix = $false
$script:GatewayToken = ""
$script:OC_ROOT = ""

# -- Colors & output ---------------------------------------------------
function Info($msg)    { Write-Host "  >" $msg -ForegroundColor Cyan }
function Ok($msg)      { Write-Host "  OK" $msg -ForegroundColor Green }
function Warn($msg)    { Write-Host "  !!" $msg -ForegroundColor Yellow }
function Fail($msg)    { Write-Host "  X" $msg -ForegroundColor Red; throw $msg }
function Phase($n, $title) {
    Write-Host ""
    Write-Host "[$n/$TOTAL_PHASES] $title" -ForegroundColor White
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
}
function Divider { Write-Host "  -----------------------------------------" -ForegroundColor DarkGray }

# -- CLI parsing -------------------------------------------------------
function Show-Usage {
    @"
OpenClaw Installer (Windows)

Usage:
  irm https://install9.ai/openclaw-win | iex
  .\install.ps1 [OPTIONS]
  install9 [OPTIONS]                          (after first install)
  powershell -ExecutionPolicy Bypass -File .\install.ps1 [OPTIONS]

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
"@
    exit 0
}

function Parse-Args {
    param([string[]]$Arguments)

    # Support secrets via environment variables (safer than CLI args visible in process list)
    if ($env:OPENCLAW_MODEL_PROVIDER) { $script:ArgModelProvider = $env:OPENCLAW_MODEL_PROVIDER; Remove-Item env:OPENCLAW_MODEL_PROVIDER -EA SilentlyContinue }
    if ($env:OPENCLAW_MODEL_API_KEY)  { $script:ArgModelApiKey = $env:OPENCLAW_MODEL_API_KEY; Remove-Item env:OPENCLAW_MODEL_API_KEY -EA SilentlyContinue }
    if ($env:OPENCLAW_MODEL_NAME)     { $script:ArgModelName = $env:OPENCLAW_MODEL_NAME; Remove-Item env:OPENCLAW_MODEL_NAME -EA SilentlyContinue }
    if ($env:OPENCLAW_MODEL_BASE_URL) { $script:ArgModelBaseUrl = $env:OPENCLAW_MODEL_BASE_URL; Remove-Item env:OPENCLAW_MODEL_BASE_URL -EA SilentlyContinue }
    if ($env:OPENCLAW_FEISHU_APP_ID)     { $script:ArgFeishuAppId = $env:OPENCLAW_FEISHU_APP_ID; Remove-Item env:OPENCLAW_FEISHU_APP_ID -EA SilentlyContinue }
    if ($env:OPENCLAW_FEISHU_APP_SECRET) { $script:ArgFeishuAppSecret = $env:OPENCLAW_FEISHU_APP_SECRET; Remove-Item env:OPENCLAW_FEISHU_APP_SECRET -EA SilentlyContinue }
    if ($env:OPENCLAW_TELEGRAM_TOKEN)    { $script:ArgTelegramToken = $env:OPENCLAW_TELEGRAM_TOKEN; Remove-Item env:OPENCLAW_TELEGRAM_TOKEN -EA SilentlyContinue }
    if ($env:OPENCLAW_SLACK_BOT_TOKEN)   { $script:ArgSlackBotToken = $env:OPENCLAW_SLACK_BOT_TOKEN; Remove-Item env:OPENCLAW_SLACK_BOT_TOKEN -EA SilentlyContinue }
    if ($env:OPENCLAW_SLACK_APP_TOKEN)   { $script:ArgSlackAppToken = $env:OPENCLAW_SLACK_APP_TOKEN; Remove-Item env:OPENCLAW_SLACK_APP_TOKEN -EA SilentlyContinue }
    if ($env:OPENCLAW_DISCORD_TOKEN)     { $script:ArgDiscordToken = $env:OPENCLAW_DISCORD_TOKEN; Remove-Item env:OPENCLAW_DISCORD_TOKEN -EA SilentlyContinue }

    $i = 0
    while ($i -lt $Arguments.Count) {
        $arg = $Arguments[$i]
        switch ($arg) {
            '--non-interactive'   { $script:NonInteractive = $true }
            '--channel'           { $i++; if ($i -ge $Arguments.Count) { Fail "--channel requires a value" }; $script:ArgChannel = $Arguments[$i] }
            '--feishu-app-id'     { $i++; if ($i -ge $Arguments.Count) { Fail "--feishu-app-id requires a value" }; $script:ArgFeishuAppId = $Arguments[$i] }
            '--feishu-app-secret' { $i++; if ($i -ge $Arguments.Count) { Fail "--feishu-app-secret requires a value" }; $script:ArgFeishuAppSecret = $Arguments[$i] }
            '--feishu-domain'     { $i++; if ($i -ge $Arguments.Count) { Fail "--feishu-domain requires a value" }; $script:ArgFeishuDomain = $Arguments[$i] }
            '--telegram-token'    { $i++; if ($i -ge $Arguments.Count) { Fail "--telegram-token requires a value" }; $script:ArgTelegramToken = $Arguments[$i] }
            '--slack-bot-token'   { $i++; if ($i -ge $Arguments.Count) { Fail "--slack-bot-token requires a value" }; $script:ArgSlackBotToken = $Arguments[$i] }
            '--slack-app-token'   { $i++; if ($i -ge $Arguments.Count) { Fail "--slack-app-token requires a value" }; $script:ArgSlackAppToken = $Arguments[$i] }
            '--discord-token'     { $i++; if ($i -ge $Arguments.Count) { Fail "--discord-token requires a value" }; $script:ArgDiscordToken = $Arguments[$i] }
            '--model-provider'    { $i++; if ($i -ge $Arguments.Count) { Fail "--model-provider requires a value" }; $script:ArgModelProvider = $Arguments[$i] }
            '--model-name'        { $i++; if ($i -ge $Arguments.Count) { Fail "--model-name requires a value" }; $script:ArgModelName = $Arguments[$i] }
            '--model-api-key'     { $i++; if ($i -ge $Arguments.Count) { Fail "--model-api-key requires a value" }; $script:ArgModelApiKey = $Arguments[$i] }
            '--model-base-url'    { $i++; if ($i -ge $Arguments.Count) { Fail "--model-base-url requires a value" }; $script:ArgModelBaseUrl = $Arguments[$i] }
            '--skip-model'        { $script:ArgSkipModel = $true }
            '--uninstall'         { $script:ArgUninstall = $true }
            '--self-update'       { $script:ArgSelfUpdate = $true }
            '--skip-channel'      { $script:ArgSkipChannel = $true }
            '--skip-security'     { $script:ArgSkipSecurity = $true }
            '--skip-deps'         { $script:ArgSkipDeps = $true }
            { $_ -in '-h','--help' }    { Show-Usage }
            { $_ -in '-v','--version' } { Write-Host "openclaw-installer $INSTALLER_VERSION"; exit 0 }
            default {
                if ($script:NonInteractive) { Fail "Unknown option: $arg" }
                else { Warn "Unknown option: $arg" }
            }
        }
        $i++
    }
}

# -- Prompt helpers ----------------------------------------------------
function Prompt-Input {
    param([string]$Msg, [string]$Default = "")
    if ($script:NonInteractive) { return $Default }
    if ($Default) {
        Write-Host "  $Msg [$Default]: " -NoNewline
    } else {
        Write-Host "  ${Msg}: " -NoNewline
    }
    $userInput = [Console]::ReadLine()
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        if ($Default) { return $Default }
        while ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-Host "  Cannot be empty" -ForegroundColor Red
            Write-Host "  ${Msg}: " -NoNewline
            $userInput = [Console]::ReadLine()
        }
    }
    return $userInput
}

function Prompt-Optional {
    param([string]$Msg, [string]$Default = "")
    if ($script:NonInteractive) { return $Default }
    Write-Host "  $Msg [$Default]: " -NoNewline
    $userInput = [Console]::ReadLine()
    if ([string]::IsNullOrWhiteSpace($userInput)) { return $Default }
    return $userInput
}

function Prompt-Secret {
    param([string]$Msg)
    if ($script:NonInteractive) { return "" }
    while ($true) {
        $secure = Read-Host -Prompt "  $Msg" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        if (-not [string]::IsNullOrWhiteSpace($plain)) { return $plain }
        Write-Host "  Cannot be empty" -ForegroundColor Red
    }
}

function Confirm {
    param([string]$Msg)
    if ($script:NonInteractive) { return $true }
    Write-Host "  $Msg [Y/n]: " -NoNewline
    $ans = [Console]::ReadLine()
    return ([string]::IsNullOrWhiteSpace($ans) -or $ans -match '^[Yy]')
}

function Confirm-DefaultNo {
    param([string]$Msg)
    if ($script:NonInteractive) { return $false }
    Write-Host "  $Msg [y/N]: " -NoNewline
    $ans = [Console]::ReadLine()
    return ($ans -match '^[Yy]')
}

# -- Platform helpers --------------------------------------------------
$script:Arch = ""
$script:PkgMgr = ""
$script:IsAdmin = $false

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Refresh-Path {
    # Rebuild from registry and merge with current session entries to preserve
    # paths added by fnm, nvm, or other tools during this session
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $registryPaths = "$machinePath;$userPath" -split ';' | Where-Object { $_ }
    $currentPaths = $env:Path -split ';' | Where-Object { $_ }
    # Add current session paths that aren't in registry (e.g., fnm shims)
    $merged = $registryPaths
    foreach ($p in $currentPaths) {
        if ($p -notin $registryPaths) { $merged += $p }
    }
    $env:Path = ($merged -join ';')
}

function Config-Read {
    param([string]$Key)
    try {
        $env:OC_KEY = $Key
        $env:OC_FILE = $OPENCLAW_CONFIG
        $result = & node -e '
            try {
                const c = JSON.parse(require("fs").readFileSync(process.env.OC_FILE, "utf8"));
                const keys = process.env.OC_KEY.split(".");
                let v = c;
                for (const k of keys) v = v?.[k];
                const out = v ?? "";
                if (typeof out === "object") console.log(JSON.stringify(out));
                else console.log(String(out));
            } catch { console.log(""); }
        ' 2>$null
        return ($result | Out-String).Trim()
    } catch { return "" }
}

function Config-Backup {
    if (Test-Path $OPENCLAW_CONFIG) {
        $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
        $bakFile = "$OPENCLAW_CONFIG.bak.$timestamp"
        Copy-Item $OPENCLAW_CONFIG $bakFile
        # Restrict backup file permissions
        try {
            $acl = Get-Acl $bakFile
            $acl.SetAccessRuleProtection($true, $false)
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $env:USERNAME, "FullControl", "Allow")
            $acl.SetAccessRule($rule)
            Set-Acl $bakFile $acl -ErrorAction SilentlyContinue
        } catch { }
        # Keep only the last 5 backups
        $backups = Get-ChildItem "$OPENCLAW_CONFIG.bak.*" -ErrorAction SilentlyContinue | Sort-Object Name
        if ($backups.Count -gt 5) {
            $backups | Select-Object -First ($backups.Count - 5) | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}

function Harden-ConfigPermissions {
    if (Test-Path $OPENCLAW_CONFIG) {
        $acl = Get-Acl $OPENCLAW_CONFIG
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl $OPENCLAW_CONFIG $acl -ErrorAction SilentlyContinue
    }
}

function Generate-Token {
    $bytes = [byte[]]::new(32)
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return ([BitConverter]::ToString($bytes) -replace '-','').ToLower()
}

function Retry {
    param([int]$Max, [int]$Delay, [scriptblock]$Action)
    $attempt = 1
    while ($true) {
        try {
            & $Action 2>$null | Out-Null
            return $true
        } catch { }
        if ($attempt -ge $Max) { return $false }
        Start-Sleep -Seconds $Delay
        $attempt++
    }
}

function Write-EnvToProfile {
    param([string]$VarName, [string]$Value, [string]$Comment)
    $profileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

    $line = "`$env:$VarName = '$($Value -replace "'","''")'"
    $content = Get-Content $PROFILE -ErrorAction SilentlyContinue

    if ($content -and ($content | Select-String $VarName)) {
        $content = $content | ForEach-Object {
            if ($_ -match $VarName) { $line } else { $_ }
        }
        $content | Set-Content $PROFILE
    } else {
        Add-Content $PROFILE "`n# $Comment`n$line"
    }

    [Environment]::SetEnvironmentVariable($VarName, $Value, 'User')
}

function Write-TokenToProfile {
    param([string]$Token)
    Write-EnvToProfile "OPENCLAW_GATEWAY_TOKEN" $Token "OpenClaw Gateway Token"
}

# ======================================================================
#  PHASE 1: Banner & environment detection
# ======================================================================
function Show-Banner {
    Write-Host ""
    Write-Host "  +==========================================+" -ForegroundColor White
    Write-Host "  |  " -ForegroundColor White -NoNewline
    Write-Host "OpenClaw" -ForegroundColor Cyan -NoNewline
    Write-Host " - Installer " -NoNewline
    Write-Host "v$INSTALLER_VERSION" -ForegroundColor DarkGray -NoNewline
    Write-Host "             |" -ForegroundColor White
    Write-Host "  +==========================================+" -ForegroundColor White
    Write-Host ""
}

function Phase1-Detect {
    Phase 1 "Detecting environment"

    # Architecture
    $script:Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { 'x64' }
        'ARM64' { 'arm64' }
        default { $env:PROCESSOR_ARCHITECTURE }
    }

    # Package manager
    if (Get-Command winget -ErrorAction SilentlyContinue) { $script:PkgMgr = "winget" }
    elseif (Get-Command choco -ErrorAction SilentlyContinue) { $script:PkgMgr = "choco" }
    elseif (Get-Command scoop -ErrorAction SilentlyContinue) { $script:PkgMgr = "scoop" }

    $script:IsAdmin = Test-Admin

    Info "OS: Windows ($script:Arch)"
    Info "Package manager: $(if ($script:PkgMgr) { $script:PkgMgr } else { 'none detected' })"
    Info "Admin: $(if ($script:IsAdmin) { 'yes' } else { 'no' })"
    Info "Profile: $PROFILE"

    # Check existing installation
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        $ver = & openclaw --version 2>$null
        if (-not $ver) { $ver = "unknown" }
        Ok "OpenClaw already installed: $ver"
    } else {
        Info "OpenClaw not found - will install"
    }
}

# ======================================================================
#  PHASE 2: Dependencies
# ======================================================================
function Install-Pkg {
    param([string]$Name, [string]$WingetId = "", [string]$ChocoName = "", [string]$ScoopName = "")
    if (-not $script:PkgMgr) { Fail "No package manager found. Install '$Name' manually and re-run." }
    Info "Installing $Name via $script:PkgMgr..."
    switch ($script:PkgMgr) {
        'winget' {
            $id = if ($WingetId) { $WingetId } else { $Name }
            & winget install --id $id --accept-package-agreements --accept-source-agreements --silent 2>&1 | Select-Object -Last 3
        }
        'choco' {
            $pkg = if ($ChocoName) { $ChocoName } else { $Name }
            & choco install $pkg -y 2>&1 | Select-Object -Last 3
        }
        'scoop' {
            $pkg = if ($ScoopName) { $ScoopName } else { $Name }
            & scoop install $pkg 2>&1 | Select-Object -Last 3
        }
    }
    Refresh-Path
}

function Install-NodeViaFnm {
    Info "Installing Node.js $MIN_NODE_MAJOR via fnm..."
    if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
        Info "Installing fnm first..."
        switch ($script:PkgMgr) {
            'winget' { & winget install --id Schniz.fnm --accept-package-agreements --accept-source-agreements --silent 2>&1 | Select-Object -Last 3 }
            'choco'  { & choco install fnm -y 2>&1 | Select-Object -Last 3 }
            'scoop'  { & scoop install fnm 2>&1 | Select-Object -Last 3 }
            default  { Fail "No package manager to install fnm. Install Node.js $MIN_NODE_MAJOR manually." }
        }
        Refresh-Path
    }

    # Set up fnm environment for current session
    # Only execute lines that match expected fnm env patterns (env var assignments / PATH appends)
    $fnmEnv = & fnm env --use-on-cd 2>$null
    if ($fnmEnv) {
        $fnmEnv | ForEach-Object {
            # Allow only: $env:VAR = "value", Set-Item, or lines with fnm path manipulation
            if ($_ -match '^\s*\$env:\w+\s*=' -or $_ -match '^\s*Set-Item\s' -or [string]::IsNullOrWhiteSpace($_)) {
                Invoke-Expression $_
            }
            # Silently skip anything that doesn't match expected patterns
        }
    }

    & fnm install $MIN_NODE_MAJOR 2>&1 | Select-Object -Last 3
    & fnm use $MIN_NODE_MAJOR 2>$null
    & fnm default $MIN_NODE_MAJOR 2>$null

    Refresh-Path
}

function Install-NodeViaPkg {
    switch ($script:PkgMgr) {
        'winget' {
            Info "Installing Node.js via winget..."
            & winget install --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent 2>&1 | Select-Object -Last 3
            Refresh-Path
        }
        'choco' {
            Info "Installing Node.js via choco..."
            & choco install nodejs-lts -y 2>&1 | Select-Object -Last 3
            Refresh-Path
        }
        'scoop' {
            Info "Installing Node.js via scoop..."
            & scoop install nodejs-lts 2>&1 | Select-Object -Last 3
            Refresh-Path
        }
        default { Install-NodeViaFnm }
    }
}

function Phase2-Deps {
    Phase 2 "Checking dependencies"

    if ($script:ArgSkipDeps) { Info "Skipped (--skip-deps)"; return }

    # -- git --
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitVer = & git --version 2>&1 | Select-Object -First 1
        Ok "git: $gitVer"
    } else {
        Install-Pkg -Name "git" -WingetId "Git.Git" -ChocoName "git" -ScoopName "git"
    }

    # -- curl (built-in on Windows 10+) --
    Ok "curl: built-in (Invoke-WebRequest)"

    # -- openssl (not needed - using .NET crypto) --
    Ok "openssl: not needed (using .NET crypto)"

    # -- jq (not needed - using ConvertFrom-Json) --
    Ok "jq: not needed (using ConvertFrom-Json)"

    # -- Node.js --
    $nodeOk = $false
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $nodeVerStr = & node --version 2>$null
        if (-not $nodeVerStr) { $nodeVerStr = "v0" }
        $nodeMajor = [int]($nodeVerStr.TrimStart('v').Split('.')[0])
        if ($nodeMajor -ge $MIN_NODE_MAJOR) {
            Ok "Node.js: $nodeVerStr (meets >= $MIN_NODE_MAJOR)"
            $nodeOk = $true
        } else {
            Warn "Node.js $nodeVerStr is below required v$MIN_NODE_MAJOR"
        }
    }

    if (-not $nodeOk) {
        if ($script:PkgMgr) {
            Write-Host ""
            Info "Node.js ${MIN_NODE_MAJOR}+ is required. Choose install method:"
            Write-Host "    1) " -NoNewline; Write-Host "fnm" -ForegroundColor White -NoNewline; Write-Host " (recommended, user-space)"
            Write-Host "    2) " -NoNewline; Write-Host "System package manager" -ForegroundColor White -NoNewline; Write-Host " ($($script:PkgMgr))"
            Write-Host ""

            $choice = Prompt-Input "Select [1/2]" "1"
            if ($choice -eq "2") { Install-NodeViaPkg }
            else { Install-NodeViaFnm }
        } else {
            Install-NodeViaFnm
        }

        Refresh-Path
        if (Get-Command node -ErrorAction SilentlyContinue) {
            $ver = & node --version 2>$null
            Ok "Node.js installed: $ver"
        } else {
            Fail "Node.js installation failed. Install Node.js $MIN_NODE_MAJOR+ manually and re-run."
        }
    }

    # -- npm --
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $npmVer = & npm --version 2>$null
        Ok "npm: $npmVer"
    } else {
        Fail "npm not found. It should come with Node.js - check your installation."
    }
}

# ======================================================================
#  PHASE 3: Install OpenClaw
# ======================================================================
function Phase3-Install {
    Phase 3 "Installing OpenClaw"

    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        $currentVerRaw = & openclaw --version 2>$null
        if ($currentVerRaw -match '(\d+\.\d+\.\d+)') { $currentVer = $Matches[1] } else { $currentVer = "unknown" }
        Ok "OpenClaw $currentVer already installed"

        if (Confirm-DefaultNo "Check for updates?") {
            Info "Checking latest version..."
            $latest = & npm view $OPENCLAW_PKG version 2>$null
            if ($latest -and $latest -ne $currentVer) {
                Info "New version available: $latest (current: $currentVer)"
                if (Confirm "Upgrade to ${latest}?") {
                    $upgradeResult = & npm install -g "${OPENCLAW_PKG}@latest" 2>&1 | Out-String
                    if ($LASTEXITCODE -eq 0) {
                        $newVerRaw = & openclaw --version 2>$null
                        if ($newVerRaw -match '(\d+\.\d+\.\d+)') { $newVer = $Matches[1] } else { $newVer = $newVerRaw }
                        Ok "Upgraded to $newVer"
                    } else {
                        Warn "Upgrade failed. Try manually: npm install -g ${OPENCLAW_PKG}@latest"
                        Warn "If you see ENOTEMPTY, run: npm cache clean --force && npm install -g ${OPENCLAW_PKG}@latest"
                    }
                }
            } else {
                Ok "Already on latest version"
            }
        }
    } else {
        Info "Installing $OPENCLAW_PKG globally via npm..."
        & npm install -g $OPENCLAW_PKG 2>&1 | Select-Object -Last 5
        Refresh-Path
        if (Get-Command openclaw -ErrorAction SilentlyContinue) {
            $ver = & openclaw --version 2>$null
            Ok "OpenClaw $ver installed"
        } else {
            Fail "Installation failed. Try: npm install -g $OPENCLAW_PKG"
        }
    }

    # Locate installation path (Windows: no lib/ intermediate dir)
    $ocBin = (Get-Command openclaw -ErrorAction SilentlyContinue).Source
    $script:OC_ROOT = ""
    if ($ocBin) {
        $npmPrefix = & npm prefix -g 2>$null
        if ($npmPrefix) {
            $candidate = Join-Path $npmPrefix "node_modules\openclaw"
            if (Test-Path $candidate) { $script:OC_ROOT = $candidate }
        }
    }
    if (-not $script:OC_ROOT -or -not (Test-Path $script:OC_ROOT)) {
        # Fallback: common locations
        $fallbacks = @(
            (Join-Path $env:APPDATA "npm\node_modules\openclaw"),
            (Join-Path $env:ProgramFiles "nodejs\node_modules\openclaw")
        )
        foreach ($p in $fallbacks) {
            if (Test-Path $p) { $script:OC_ROOT = $p; break }
        }
    }
    if (-not $script:OC_ROOT -or -not (Test-Path $script:OC_ROOT)) {
        Fail "Cannot locate openclaw installation directory"
    }
    Ok "Install path: $($script:OC_ROOT)"
}

# ======================================================================
#  PHASE 4: Initialize configuration
# ======================================================================
function Phase4-Init {
    Phase 4 "Initializing configuration"

    if (-not (Test-Path $OPENCLAW_CONFIG)) {
        Info "No config found. Running initial setup..."
        if (-not (Test-Path $OPENCLAW_CONFIG_DIR)) {
            New-Item -ItemType Directory -Path $OPENCLAW_CONFIG_DIR -Force | Out-Null
        }
        try { & openclaw setup --non-interactive 2>&1 | Select-Object -Last 5 } catch { Warn "openclaw setup returned an error, continuing..." }

        if (-not (Test-Path $OPENCLAW_CONFIG)) {
            Info "Creating minimal config..."
            @'
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
'@ | ForEach-Object { [IO.File]::WriteAllText($OPENCLAW_CONFIG, $_, [Text.Encoding]::UTF8) }
            Ok "Minimal config created"
            Harden-ConfigPermissions
        }
    } else {
        Ok "Config exists: $OPENCLAW_CONFIG"
    }

    # -- Model Setup --
    if (-not $script:ArgSkipModel) {
        $existingModel = Config-Read "agents.defaults.model.primary"

        if ($existingModel -and -not $script:ArgModelProvider) {
            Ok "Model: $existingModel (already configured)"
        } else {
            $provider = $script:ArgModelProvider
            if (-not $provider -and -not $script:NonInteractive) {
                Write-Host ""
                Write-Host "  Select LLM provider:"
                Write-Host "    1)  " -NoNewline; Write-Host "anthropic" -ForegroundColor White -NoNewline; Write-Host "          - Claude"
                Write-Host "    2)  " -NoNewline; Write-Host "openai" -ForegroundColor White -NoNewline; Write-Host "             - GPT / o-series"
                Write-Host "    3)  " -NoNewline; Write-Host "openai-codex" -ForegroundColor White -NoNewline; Write-Host "       - Codex (ChatGPT Plus OAuth)"
                Write-Host "    4)  " -NoNewline; Write-Host "google" -ForegroundColor White -NoNewline; Write-Host "             - Gemini"
                Write-Host "    5)  " -NoNewline; Write-Host "openrouter" -ForegroundColor White -NoNewline; Write-Host "         - OpenRouter (100+ models)"
                Write-Host "    6)  " -NoNewline; Write-Host "xai" -ForegroundColor White -NoNewline; Write-Host "                - Grok"
                Write-Host "    7)  " -NoNewline; Write-Host "mistral" -ForegroundColor White -NoNewline; Write-Host "            - Mistral"
                Write-Host "    8)  " -NoNewline; Write-Host "groq" -ForegroundColor White -NoNewline; Write-Host "               - Groq (fast inference)"
                Write-Host "    9)  " -NoNewline; Write-Host "minimax" -ForegroundColor White -NoNewline; Write-Host "            - MiniMax"
                Write-Host "    10) " -NoNewline; Write-Host "zai" -ForegroundColor White -NoNewline; Write-Host "                - GLM / ChatGLM (Zhipu AI)"
                Write-Host "    11) " -NoNewline; Write-Host "ollama" -ForegroundColor White -NoNewline; Write-Host "             - Local models (no API key)"
                Write-Host "    12) " -NoNewline; Write-Host "openai-compatible" -ForegroundColor White -NoNewline; Write-Host "  - Custom endpoint"
                Write-Host "    s)  Skip"
                Write-Host ""

                $choice = Prompt-Input "Select provider" "1"
                $provider = switch ($choice) {
                    { $_ -in '1','anthropic' }          { 'anthropic' }
                    { $_ -in '2','openai' }             { 'openai' }
                    { $_ -in '3','openai-codex','codex' } { 'openai-codex' }
                    { $_ -in '4','google' }             { 'google' }
                    { $_ -in '5','openrouter' }         { 'openrouter' }
                    { $_ -in '6','xai' }                { 'xai' }
                    { $_ -in '7','mistral' }            { 'mistral' }
                    { $_ -in '8','groq' }               { 'groq' }
                    { $_ -in '9','minimax' }            { 'minimax' }
                    { $_ -in '10','zai','glm' }         { 'zai' }
                    { $_ -in '11','ollama' }            { 'ollama' }
                    { $_ -in '12','openai-compatible' } { 'openai-compatible' }
                    { $_ -in 's','S' }                  { '' }
                    default { Warn "Unknown choice, skipping model setup"; '' }
                }
            }

            if ($provider) {
                # Default model and example hints per provider
                $defaultModel = ''; $modelHints = ''
                switch ($provider) {
                    'anthropic'         { $defaultModel = 'claude-sonnet-4-6';          $modelHints = 'claude-opus-4-6, claude-haiku-4-5' }
                    'openai'            { $defaultModel = 'gpt-4.1';                   $modelHints = 'gpt-4.1-mini, gpt-4.1-nano, gpt-5.4' }
                    'openai-codex'      { $defaultModel = 'gpt-5.3-codex';             $modelHints = 'gpt-5.3-codex-spark' }
                    'google'            { $defaultModel = 'gemini-2.5-flash';          $modelHints = 'gemini-3.1-flash, gemini-2.5-pro' }
                    'openrouter'        { $defaultModel = 'anthropic/claude-sonnet-4-6'; $modelHints = 'openai/gpt-4.1, deepseek/deepseek-chat' }
                    'xai'               { $defaultModel = 'grok-4';                    $modelHints = 'grok-4-1-fast-reasoning, grok-3' }
                    'mistral'           { $defaultModel = 'mistral-large-3-25-12';     $modelHints = 'devstral-2-25-12, mistral-medium-3-1-25-08' }
                    'groq'              { $defaultModel = 'llama-3.3-70b-versatile';   $modelHints = 'llama-3.1-8b-instant, mixtral-8x7b-32768' }
                    'minimax'           { $defaultModel = 'MiniMax-M2.5';              $modelHints = 'MiniMax-M2.5-highspeed' }
                    'zai'               { $defaultModel = 'glm-5';                     $modelHints = 'glm-4.7, glm-4.6' }
                    'ollama'            { $defaultModel = 'llama4';                     $modelHints = 'llama3.3, qwen2.5-coder:32b' }
                    'openai-compatible' { $defaultModel = '' }
                }

                # Prompt for model name (or use CLI arg / fallback default)
                $modelName = $script:ArgModelName
                if (-not $modelName) {
                    if (-not $script:NonInteractive) {
                        if ($modelHints) { Info "Other models: $modelHints" }
                        $modelName = Prompt-Input "Model name" $defaultModel
                    } else {
                        $modelName = $defaultModel
                    }
                }

                # Guard: openai-compatible requires a model name
                if (-not $modelName -and $provider -eq 'openai-compatible') {
                    Warn "No model name provided for openai-compatible; skipping model setup"
                    $provider = ''
                }

                # Build primary model identifier: "provider/model"
                $modelPrimary = "$provider/$modelName"

                # Determine API key env var name (per OpenClaw docs)
                $needsApiKey = $provider -notin 'openai-codex','ollama'
                $apiKeyVar = switch ($provider) {
                    'anthropic'         { 'ANTHROPIC_API_KEY' }
                    'openai'            { 'OPENAI_API_KEY' }
                    'openai-codex'      { '' }
                    'google'            { 'GEMINI_API_KEY' }
                    'openrouter'        { 'OPENROUTER_API_KEY' }
                    'xai'               { 'XAI_API_KEY' }
                    'mistral'           { 'MISTRAL_API_KEY' }
                    'groq'              { 'GROQ_API_KEY' }
                    'minimax'           { 'MINIMAX_API_KEY' }
                    'zai'               { 'ZAI_API_KEY' }
                    'ollama'            { '' }
                    'openai-compatible' { 'OPENAI_API_KEY' }
                    default             { 'OPENAI_API_KEY' }
                }

                # Get API key
                $apiKey = $script:ArgModelApiKey
                if ($needsApiKey) {
                    if (-not $apiKey -and $apiKeyVar) {
                        $apiKey = [Environment]::GetEnvironmentVariable($apiKeyVar)
                    }
                    if (-not $apiKey -and -not $script:NonInteractive -and $apiKeyVar) {
                        $apiKey = Prompt-Secret $apiKeyVar
                    }
                }

                # Special note for OAuth-based providers
                if ($provider -eq 'openai-codex' -and -not $script:NonInteractive) {
                    Info "Codex uses ChatGPT Plus OAuth - run 'openclaw auth login' after install"
                }

                # Base URL for openai-compatible
                $baseUrl = $script:ArgModelBaseUrl
                if ($provider -eq 'openai-compatible' -and -not $baseUrl -and -not $script:NonInteractive) {
                    $baseUrl = Prompt-Input "Base URL (e.g. https://api.example.com/v1)"
                }

                # Write model config to openclaw.json
                Config-Backup
                $env:MODEL_PRIMARY = $modelPrimary
                $env:MODEL_BASE_URL = if ($baseUrl) { $baseUrl } else { "" }
                $env:OC_FILE = $OPENCLAW_CONFIG
                try {
                    & node -e '
                        const fs = require("fs");
                        const f = process.env.OC_FILE;
                        const config = JSON.parse(fs.readFileSync(f, "utf8"));
                        if (!config.agents) config.agents = {};
                        if (!config.agents.defaults) config.agents.defaults = {};
                        if (!config.agents.defaults.model) config.agents.defaults.model = {};
                        config.agents.defaults.model.primary = process.env.MODEL_PRIMARY;
                        if (process.env.MODEL_BASE_URL) config.agents.defaults.model.baseUrl = process.env.MODEL_BASE_URL;
                        else delete config.agents.defaults.model.baseUrl;
                        const tmp = f + ".tmp." + process.pid;
                        fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
                        fs.renameSync(tmp, f);
                    '
                } finally {
                    Remove-Item env:MODEL_PRIMARY -ErrorAction SilentlyContinue
                    Remove-Item env:MODEL_BASE_URL -ErrorAction SilentlyContinue
                }
                Harden-ConfigPermissions
                Ok "Model: $modelPrimary"

                # Write API key to profile
                if ($needsApiKey) {
                    if ($apiKey -and $apiKeyVar) {
                        Write-EnvToProfile $apiKeyVar $apiKey "OpenClaw LLM API Key"
                        [Environment]::SetEnvironmentVariable($apiKeyVar, $apiKey)
                        Ok "API key written to profile and user environment"
                    } elseif ($apiKeyVar) {
                        Warn "No API key provided - set $apiKeyVar before starting OpenClaw"
                    }
                }
            }
        }
    }

    # -- Gateway Token --
    Info "Checking gateway token..."

    $authToken = Config-Read "gateway.auth.token"
    $remoteToken = Config-Read "gateway.remote.token"

    $script:GatewayToken = ""
    $script:NeedTokenFix = $false

    if (-not $authToken -or $authToken -eq "YOUR_NEW_GATEWAY_TOKEN") {
        Info "Generating new gateway token..."
        $script:GatewayToken = Generate-Token
        $script:NeedTokenFix = $true
    } elseif ($authToken -ne $remoteToken) {
        Info "Syncing auth.token -> remote.token..."
        $script:GatewayToken = $authToken
        $script:NeedTokenFix = $true
    } else {
        $script:GatewayToken = $authToken
        Ok "Gateway token: configured"
    }

    if ($script:NeedTokenFix) {
        Config-Backup

        $env:GATEWAY_TOKEN = $script:GatewayToken
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
                const fs = require("fs");
                const f = process.env.OC_FILE;
                const config = JSON.parse(fs.readFileSync(f, "utf8"));
                if (!config.gateway) config.gateway = {};
                config.gateway.mode = "local";
                if (!config.gateway.auth) config.gateway.auth = {};
                config.gateway.auth.mode = "token";
                config.gateway.auth.token = process.env.GATEWAY_TOKEN;
                if (!config.gateway.remote) config.gateway.remote = {};
                config.gateway.remote.token = process.env.GATEWAY_TOKEN;
                const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
            '
        } finally {
            Remove-Item env:GATEWAY_TOKEN -ErrorAction SilentlyContinue
        }

        Ok "Gateway token: set"
        Harden-ConfigPermissions

        Write-TokenToProfile $script:GatewayToken
        Ok "Token written to profile and user environment"
    }

    $env:OPENCLAW_GATEWAY_TOKEN = $script:GatewayToken

    # -- Workspace directory --
    $workspace = Config-Read "agents.defaults.workspace"
    if ($workspace) {
        $workspace = $workspace -replace '^~', $env:USERPROFILE
        if (-not (Test-Path $workspace)) {
            New-Item -ItemType Directory -Path $workspace -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# ======================================================================
#  PHASE 5: Gateway service
# ======================================================================
function Phase5-Gateway {
    Phase 5 "Setting up gateway service"

    # Strategy A: Try openclaw's native gateway install
    $nativeInstallOk = $false
    try {
        Info "Installing gateway service..."
        & openclaw gateway install --force 2>&1 | Select-Object -Last 3
        Info "Starting gateway..."
        & openclaw gateway restart 2>&1 | Select-Object -First 1
        $nativeInstallOk = $true
    } catch {
        Warn "Native gateway install not available, using fallback..."
    }

    if (-not $nativeInstallOk) {
        if ($script:IsAdmin) {
            # Strategy B: Windows Scheduled Task (runs at logon, no NSSM dependency)
            Info "Creating scheduled task for gateway..."
            $nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
            $gwScript = Join-Path $script:OC_ROOT "bin\openclaw"

            $existingTask = Get-ScheduledTask -TaskName "OpenClawGateway" -ErrorAction SilentlyContinue
            if ($existingTask) {
                Unregister-ScheduledTask -TaskName "OpenClawGateway" -Confirm:$false -ErrorAction SilentlyContinue
            }

            $action = New-ScheduledTaskAction -Execute $nodePath -Argument "`"$gwScript`" gateway"
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
            Register-ScheduledTask -TaskName "OpenClawGateway" -Action $action -Trigger $trigger -Settings $settings -RunLevel Limited | Out-Null
            try {
                Start-ScheduledTask -TaskName "OpenClawGateway"
                Ok "Gateway scheduled task created and started"
            } catch {
                Ok "Gateway scheduled task created (will start at next logon)"
            }
        } else {
            # Strategy C: Background process (non-persistent)
            Warn "Not running as admin - starting gateway as background process"
            $gwLog = Join-Path $OPENCLAW_CONFIG_DIR "logs\gateway.log"
            $gwLogDir = Split-Path $gwLog -Parent
            if (-not (Test-Path $gwLogDir)) { New-Item -ItemType Directory -Path $gwLogDir -Force | Out-Null }

            $proc = Start-Process -FilePath node -ArgumentList "`"$(Join-Path $script:OC_ROOT 'bin\openclaw')`" gateway" `
                -RedirectStandardOutput $gwLog -RedirectStandardError "$gwLog.err" `
                -WindowStyle Hidden -PassThru
            Ok "Gateway started (PID: $($proc.Id))"
            Info "Log: $gwLog"
            Warn "Gateway will stop when you log off."
            Warn "Run as admin to create a persistent scheduled task."
        }
    }

    # Verify connection with retries
    Info "Verifying gateway connection..."
    $connected = Retry -Max 5 -Delay 3 -Action { & openclaw cron list }
    if ($connected) {
        Ok "Gateway: running and connected"
    } else {
        Warn "Gateway connection timed out"
        Warn "Try: openclaw gateway restart; openclaw status"
    }
}

# ======================================================================
#  PHASE 6: Channel setup
# ======================================================================

# -- Feishu / Lark --
function Setup-ChannelFeishu {
    $feishuExt = Join-Path $script:OC_ROOT "extensions\feishu"
    if (-not (Test-Path $feishuExt)) {
        Warn "Feishu extension not found at $feishuExt, skipping"
        return
    }

    # Install SDK dependency
    $sdkPath = Join-Path $feishuExt "node_modules\@larksuiteoapi\node-sdk"
    if (-not (Test-Path $sdkPath)) {
        Info "Installing @larksuiteoapi/node-sdk..."
        Push-Location $feishuExt
        & npm install "@larksuiteoapi/node-sdk" --save 2>&1 | Select-Object -Last 1
        Pop-Location
        Ok "Feishu SDK installed"
    } else {
        Ok "Feishu SDK: present"
    }

    # Check existing config
    $existingAppId = Config-Read "channels.feishu.appId"
    $skipConfig = $false
    if ($existingAppId) {
        Warn "Feishu already configured (App ID: $existingAppId)"
        if (-not (Confirm "Reconfigure?")) { $skipConfig = $true }
    }

    if (-not $skipConfig) {
        Write-Host ""
        Write-Host "  Feishu App Setup Guide (before install):" -ForegroundColor Cyan
        Write-Host "    1. Go to " -NoNewline; Write-Host "https://open.feishu.cn" -ForegroundColor White
        Write-Host "    2. Create an app -> get " -NoNewline; Write-Host "App ID" -ForegroundColor Yellow -NoNewline; Write-Host " and " -NoNewline; Write-Host "App Secret" -ForegroundColor Yellow
        Write-Host "    3. Enable " -NoNewline; Write-Host "bot capability" -ForegroundColor White -NoNewline; Write-Host " (add app capability -> Bot)"
        Write-Host "    4. Add permissions (Permissions -> API Permissions):"
        Write-Host "       im:message:send_as_bot                 Send messages" -ForegroundColor DarkGray
        Write-Host "       im:message.p2p_msg:readonly             Receive DMs" -ForegroundColor DarkGray
        Write-Host "       im:message.group_at_msg:readonly        Receive @mentions" -ForegroundColor DarkGray
        Write-Host "       im:resource                             Images & files" -ForegroundColor DarkGray
        Write-Host "       im:chat.access_event.bot_p2p_chat:read  Chat events" -ForegroundColor DarkGray
        Write-Host "       " -NoNewline; Write-Host "Tip: " -ForegroundColor White -NoNewline; Write-Host "Import feishu-scopes.json from the install9 repo" -ForegroundColor Cyan
        Write-Host "       to add all permissions at once." -ForegroundColor DarkGray
        Write-Host "       Need more? Add scopes as needed (e.g. contact, chat members)." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Steps 5-6 will be done after the installer configures the channel:" -ForegroundColor Cyan
        Write-Host "    5. Events -> Use " -NoNewline; Write-Host "WebSocket" -ForegroundColor White -NoNewline; Write-Host " mode"
        Write-Host "       Requires OpenClaw running first - the installer will start it," -ForegroundColor DarkGray
        Write-Host "       then Feishu can detect the connection." -ForegroundColor DarkGray
        Write-Host "    6. Publish the app version (Version Management -> Create Version)"
        Write-Host ""

        $appId = if ($script:ArgFeishuAppId) { $script:ArgFeishuAppId } else { Prompt-Input "App ID" $existingAppId }
        $appSecret = if ($script:ArgFeishuAppSecret) { $script:ArgFeishuAppSecret } else { Prompt-Secret "App Secret" }

        if (-not $appSecret) { Warn "No App Secret provided, skipping Feishu setup"; return }

        if ($appId -notmatch '^cli_[a-zA-Z0-9]{14,}$') {
            Warn "App ID format may be incorrect (expected: cli_xxxxxxxxxxxxxxxx)"
        }

        # Domain
        $domain = $script:ArgFeishuDomain
        if (-not $script:NonInteractive -and -not $script:ArgFeishuAppId) {
            Write-Host ""
            Write-Host "    1) " -NoNewline; Write-Host "feishu" -ForegroundColor White -NoNewline; Write-Host " - China mainland"
            Write-Host "    2) " -NoNewline; Write-Host "lark" -ForegroundColor White -NoNewline; Write-Host "   - International"
            Write-Host ""
            $domainChoice = Prompt-Input "Select [1/2]" "1"
            $domain = if ($domainChoice -eq "2") { "lark" } else { "feishu" }
        }

        # Write config (secrets via env vars, cleared after use)
        Config-Backup
        $env:FEISHU_APP_ID = $appId
        $env:FEISHU_APP_SECRET = $appSecret
        $env:FEISHU_DOMAIN = $domain
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
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
                const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
            '
        } finally {
            Remove-Item env:FEISHU_APP_ID, env:FEISHU_APP_SECRET, env:FEISHU_DOMAIN -ErrorAction SilentlyContinue
        }
        Ok "Feishu config written"
        Harden-ConfigPermissions
    }

    # Restart gateway
    Info "Restarting gateway to load Feishu plugin..."
    & openclaw gateway restart 2>&1 | Select-Object -First 1
    Start-Sleep -Seconds 5

    $statusOut = & openclaw status 2>&1 | Out-String
    if ($statusOut -match 'feishu.*OK') { Ok "Feishu channel: active" }
    else { Warn "Feishu may need a moment to connect. Check: openclaw status" }

    # Post-setup reminder: event subscription and publish
    Write-Host ""
    Write-Host "  Next steps in Feishu console:" -ForegroundColor Yellow
    Write-Host "    1. " -NoNewline; Write-Host "Permissions & Scopes" -ForegroundColor White -NoNewline; Write-Host " - add these scopes:"
    Write-Host "       - " -NoNewline; Write-Host "im:message.receive_v1" -ForegroundColor White -NoNewline; Write-Host "          (receive messages)"
    Write-Host "       - " -NoNewline; Write-Host "contact:contact.base:readonly" -ForegroundColor White -NoNewline; Write-Host "  (resolve sender names)"
    Write-Host "    2. " -NoNewline; Write-Host "Events & Callbacks > Event Config" -ForegroundColor White -NoNewline; Write-Host " - add event:"
    Write-Host "       - " -NoNewline; Write-Host "im.message.receive_v1" -ForegroundColor White -NoNewline; Write-Host "          (receive messages)"
    Write-Host "    3. " -NoNewline; Write-Host "Events & Callbacks > Callback Config" -ForegroundColor White -NoNewline; Write-Host " - select " -NoNewline; Write-Host "WebSocket" -ForegroundColor White -NoNewline; Write-Host " (persistent connection)"
    Write-Host "    4. " -NoNewline; Write-Host "Version Management" -ForegroundColor White -NoNewline; Write-Host " > " -NoNewline; Write-Host "Create Version" -ForegroundColor White -NoNewline; Write-Host " > Publish"
    Write-Host ""

    # Optional test message
    if (-not $script:NonInteractive) {
        if (Confirm "Send a test message to verify?") {
            $sessionsFile = Join-Path $OPENCLAW_CONFIG_DIR "agents\main\sessions\sessions.json"
            $openId = ""

            while (-not $openId) {
                # Auto-approve any pending pairing requests
                $pairingOut = & openclaw pairing list 2>&1 | Out-String
                $pairingCodes = [regex]::Matches($pairingOut, '[A-Z0-9]{8}') | ForEach-Object { $_.Value }
                foreach ($code in $pairingCodes) {
                    Info "Auto-approving pairing code: $code"
                    & openclaw pairing approve feishu $code --notify 2>&1 | Out-Null
                }
                if ($pairingCodes) { Start-Sleep -Seconds 2 }

                if (Test-Path $sessionsFile) {
                    $sessContent = Get-Content $sessionsFile -Raw -ErrorAction SilentlyContinue
                    if ($sessContent -match '"(ou_[a-zA-Z0-9_]{32,})"') {
                        $openId = $Matches[1]
                    }
                }

                if ($openId) {
                    Info "Detected Open ID: $openId"
                    $openId = Prompt-Input "Confirm Open ID" $openId
                } else {
                    Warn "No Open ID found. Send a message to your bot in Feishu first."
                    $retry = Prompt-Optional "Press Enter to retry, or 's' to skip" ""
                    if ($retry -in 's','S') { break }
                }
            }

            if ($openId) {
                $result = & openclaw message send --channel feishu --target $openId --message "OpenClaw installed successfully! This is a test message." 2>&1 | Out-String
                if ($result -match 'Sent') { Ok "Test message sent! Check Feishu." }
                else { Warn "Send may have failed. Check: openclaw status" }
            }
        }
    }
}

# -- Telegram --
function Setup-ChannelTelegram {
    $telegramExt = Join-Path $script:OC_ROOT "extensions\telegram"
    if (-not (Test-Path $telegramExt)) {
        Warn "Telegram extension not found at $telegramExt, skipping"
        return
    }

    $existingToken = Config-Read "channels.telegram.botToken"
    $skipConfig = $false
    if ($existingToken) {
        Warn "Telegram already configured"
        if (-not (Confirm "Reconfigure?")) { $skipConfig = $true }
    }

    if (-not $skipConfig) {
        Write-Host ""
        Write-Host "  Telegram Bot Setup Guide:" -ForegroundColor Cyan
        Write-Host "    1. Open Telegram, find " -NoNewline; Write-Host "@BotFather" -ForegroundColor White
        Write-Host "    2. Send " -NoNewline; Write-Host "/newbot" -ForegroundColor White -NoNewline; Write-Host " to create a bot"
        Write-Host "    3. Copy the " -NoNewline; Write-Host "Bot Token" -ForegroundColor Yellow -NoNewline; Write-Host " (e.g. 123456:ABC-DEF...)"
        Write-Host ""

        $botToken = if ($script:ArgTelegramToken) { $script:ArgTelegramToken } else { Prompt-Secret "Bot Token" }
        if (-not $botToken) { Warn "No Bot Token provided, skipping Telegram setup"; return }

        if ($botToken -notmatch '^\d+:[a-zA-Z0-9_-]+$') {
            Warn "Token format may be incorrect (expected: 123456789:ABCdefGHI...)"
        }

        Config-Backup
        $env:TG_BOT_TOKEN = $botToken
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
                const fs = require("fs");
                const f = process.env.OC_FILE;
                const config = JSON.parse(fs.readFileSync(f, "utf8"));
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
                const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
            '
        } finally {
            Remove-Item env:TG_BOT_TOKEN -ErrorAction SilentlyContinue
        }
        Ok "Telegram config written"
        Harden-ConfigPermissions
    }

    Info "Restarting gateway to load Telegram plugin..."
    & openclaw gateway restart 2>&1 | Select-Object -First 1
    Start-Sleep -Seconds 5

    $statusOut = & openclaw status 2>&1 | Out-String
    if ($statusOut -match 'telegram.*(OK|online|polling)') { Ok "Telegram channel: active" }
    else { Warn "Telegram may need a moment to connect. Check: openclaw status" }
}

# -- Slack --
function Setup-ChannelSlack {
    $slackExt = Join-Path $script:OC_ROOT "extensions\slack"
    if (-not (Test-Path $slackExt)) {
        Warn "Slack extension not found at $slackExt, skipping"
        return
    }

    $existingToken = Config-Read "channels.slack.botToken"
    $skipConfig = $false
    if ($existingToken) {
        Warn "Slack already configured"
        if (-not (Confirm "Reconfigure?")) { $skipConfig = $true }
    }

    if (-not $skipConfig) {
        Write-Host ""
        Write-Host "  Slack App Setup Guide:" -ForegroundColor Cyan
        Write-Host "    1. Go to " -NoNewline; Write-Host "https://api.slack.com/apps" -ForegroundColor White
        Write-Host "    2. Create a new app -> From scratch"
        Write-Host "    3. Enable Socket Mode -> copy " -NoNewline; Write-Host "App-Level Token" -ForegroundColor Yellow -NoNewline; Write-Host " (xapp-...)"
        Write-Host "    4. Under OAuth & Permissions, add Bot scopes:"
        Write-Host "       chat:write, channels:history, groups:history, im:history," -ForegroundColor DarkGray
        Write-Host "       im:read, users:read, reactions:read, files:read" -ForegroundColor DarkGray
        Write-Host "    5. Install to workspace -> copy " -NoNewline; Write-Host "Bot Token" -ForegroundColor Yellow -NoNewline; Write-Host " (xoxb-...)"
        Write-Host "    6. Enable Event Subscriptions -> subscribe to:"
        Write-Host "       message.channels, message.groups, message.im, app_mention" -ForegroundColor DarkGray
        Write-Host ""

        $botToken = if ($script:ArgSlackBotToken) { $script:ArgSlackBotToken } else { Prompt-Secret "Bot Token (xoxb-...)" }
        if (-not $botToken) { Warn "No Bot Token provided, skipping Slack setup"; return }
        if ($botToken -notmatch '^xoxb-') { Warn "Bot Token should start with xoxb-" }

        $appToken = if ($script:ArgSlackAppToken) { $script:ArgSlackAppToken } else { Prompt-Secret "App Token (xapp-..., for Socket Mode)" }
        if (-not $appToken) { Warn "No App Token provided, skipping Slack setup"; return }
        if ($appToken -notmatch '^xapp-') { Warn "App Token should start with xapp-" }

        Config-Backup
        $env:SLACK_BOT_TOKEN = $botToken
        $env:SLACK_APP_TOKEN = $appToken
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
                const fs = require("fs");
                const f = process.env.OC_FILE;
                const config = JSON.parse(fs.readFileSync(f, "utf8"));
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
                const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
            '
        } finally {
            Remove-Item env:SLACK_BOT_TOKEN, env:SLACK_APP_TOKEN -ErrorAction SilentlyContinue
        }
        Ok "Slack config written"
        Harden-ConfigPermissions
    }

    Info "Restarting gateway to load Slack plugin..."
    & openclaw gateway restart 2>&1 | Select-Object -First 1
    Start-Sleep -Seconds 5

    $statusOut = & openclaw status 2>&1 | Out-String
    if ($statusOut -match 'slack.*(OK|online|connect)') { Ok "Slack channel: active" }
    else { Warn "Slack may need a moment to connect. Check: openclaw status" }
}

# -- Discord --
function Setup-ChannelDiscord {
    $discordExt = Join-Path $script:OC_ROOT "extensions\discord"
    if (-not (Test-Path $discordExt)) {
        Warn "Discord extension not found at $discordExt, skipping"
        return
    }

    $existingToken = Config-Read "channels.discord.token"
    $skipConfig = $false
    if ($existingToken) {
        Warn "Discord already configured"
        if (-not (Confirm "Reconfigure?")) { $skipConfig = $true }
    }

    if (-not $skipConfig) {
        Write-Host ""
        Write-Host "  Discord Bot Setup Guide:" -ForegroundColor Cyan
        Write-Host "    1. Go to " -NoNewline; Write-Host "https://discord.com/developers/applications" -ForegroundColor White
        Write-Host "    2. Create a new application"
        Write-Host "    3. Go to Bot -> Reset Token -> copy " -NoNewline; Write-Host "Bot Token" -ForegroundColor Yellow
        Write-Host "    4. Enable Privileged Gateway Intents:"
        Write-Host "       Message Content Intent" -ForegroundColor DarkGray
        Write-Host "    5. Go to OAuth2 -> URL Generator:"
        Write-Host "       Scopes: bot" -ForegroundColor DarkGray
        Write-Host "       Permissions: Send Messages, Read Message History," -ForegroundColor DarkGray
        Write-Host "       Add Reactions, Attach Files, Use Slash Commands" -ForegroundColor DarkGray
        Write-Host "    6. Use the generated URL to invite the bot to your server"
        Write-Host ""

        $botToken = if ($script:ArgDiscordToken) { $script:ArgDiscordToken } else { Prompt-Secret "Bot Token" }
        if (-not $botToken) { Warn "No Bot Token provided, skipping Discord setup"; return }

        Config-Backup
        $env:DISCORD_TOKEN = $botToken
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
                const fs = require("fs");
                const f = process.env.OC_FILE;
                const config = JSON.parse(fs.readFileSync(f, "utf8"));
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
                const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
            '
        } finally {
            Remove-Item env:DISCORD_TOKEN -ErrorAction SilentlyContinue
        }
        Ok "Discord config written"
        Harden-ConfigPermissions
    }

    Info "Restarting gateway to load Discord plugin..."
    & openclaw gateway restart 2>&1 | Select-Object -First 1
    Start-Sleep -Seconds 5

    $statusOut = & openclaw status 2>&1 | Out-String
    if ($statusOut -match 'discord.*(OK|online|connect)') { Ok "Discord channel: active" }
    else { Warn "Discord may need a moment to connect. Check: openclaw status" }
}

function Phase6-Channel {
    Phase 6 "Channel setup"

    if ($script:ArgSkipChannel) { Info "Skipped (--skip-channel)"; return }

    $channel = $script:ArgChannel
    if (-not $channel -and -not $script:NonInteractive) {
        Write-Host ""
        Write-Host "  Available channels:"
        Write-Host "    1) " -NoNewline; Write-Host "feishu" -ForegroundColor White -NoNewline; Write-Host "    - Feishu / Lark"
        Write-Host "    2) " -NoNewline; Write-Host "telegram" -ForegroundColor White -NoNewline; Write-Host "  - Telegram"
        Write-Host "    3) " -NoNewline; Write-Host "slack" -ForegroundColor White -NoNewline; Write-Host "     - Slack"
        Write-Host "    4) " -NoNewline; Write-Host "discord" -ForegroundColor White -NoNewline; Write-Host "   - Discord"
        Write-Host "    s) Skip"
        Write-Host ""

        $choice = Prompt-Input "Select channel" "s"
        $channel = switch ($choice) {
            { $_ -in '1','feishu' }   { 'feishu' }
            { $_ -in '2','telegram' } { 'telegram' }
            { $_ -in '3','slack' }    { 'slack' }
            { $_ -in '4','discord' }  { 'discord' }
            { $_ -in 's','S' }        { 'skip' }
            default { Warn "Unknown choice, skipping"; 'skip' }
        }
    }

    switch ($channel) {
        { $_ -in 'feishu','lark' } { Setup-ChannelFeishu }
        'telegram'                  { Setup-ChannelTelegram }
        'slack'                     { Setup-ChannelSlack }
        'discord'                   { Setup-ChannelDiscord }
        { $_ -in 'skip','' }       { Info "No channel configured" }
        default                     { Warn "Channel '$channel' is not yet supported" }
    }
}

# ======================================================================
#  PHASE 7: Security hardening & cleanup
# ======================================================================
function Phase7-Security {
    Phase 7 "Security hardening & cleanup"

    if ($script:ArgSkipSecurity) { Info "Skipped (--skip-security)"; return }
    if (-not (Test-Path $OPENCLAW_CONFIG)) { Warn "No config file, skipping"; return }

    Config-Backup
    $fixes = 0

    # -- Fix denyCommands --
    $denyCommands = Config-Read "gateway.nodes.denyCommands"
    if ($denyCommands) {
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
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
                const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
            ' 2>$null
            Ok "denyCommands: cleaned up invalid entries"
            $fixes++
        } catch { }
    }

    # -- Set workspaceOnly --
    $wsOnly = Config-Read "tools.fs.workspaceOnly"
    if ($wsOnly -ne "true") {
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
                const fs = require("fs");
                const f = process.env.OC_FILE;
                const config = JSON.parse(fs.readFileSync(f, "utf8"));
                if (!config.tools) config.tools = {};
                if (!config.tools.fs) config.tools.fs = {};
                config.tools.fs.workspaceOnly = true;
                const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
            ' 2>$null
            Ok "tools.fs.workspaceOnly: enabled"
            $fixes++
        } catch { }
    }

    # -- Disable memory search if no embedding provider --
    $memEnabled = Config-Read "agents.defaults.memorySearch.enabled"
    if ($memEnabled -ne "false") {
        if (-not $env:OPENAI_API_KEY -and -not $env:GEMINI_API_KEY -and -not $env:VOYAGE_API_KEY) {
            $env:OC_FILE = $OPENCLAW_CONFIG
            try {
                & node -e '
                    const fs = require("fs");
                    const f = process.env.OC_FILE;
                    const config = JSON.parse(fs.readFileSync(f, "utf8"));
                    if (!config.agents) config.agents = {};
                    if (!config.agents.defaults) config.agents.defaults = {};
                    if (!config.agents.defaults.memorySearch) config.agents.defaults.memorySearch = {};
                    config.agents.defaults.memorySearch.enabled = false;
                    const tmp = f + ".tmp." + process.pid;
            fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
            fs.renameSync(tmp, f);
                ' 2>$null
                Ok "memorySearch: disabled (no embedding provider found)"
                Info "To enable: set OPENAI_API_KEY or configure an embedding provider"
                $fixes++
            } catch { }
        }
    }

    # -- Clean orphan session files --
    $sessionsDir = Join-Path $OPENCLAW_CONFIG_DIR "agents\main\sessions"
    $sessionsJson = Join-Path $sessionsDir "sessions.json"
    if ((Test-Path $sessionsDir) -and (Test-Path $sessionsJson)) {
        $orphans = 0
        $sessionsContent = Get-Content $sessionsJson -Raw -ErrorAction SilentlyContinue
        $jsonlFiles = Get-ChildItem "$sessionsDir\*.jsonl" -ErrorAction SilentlyContinue
        foreach ($f in $jsonlFiles) {
            $sessionId = $f.BaseName
            if ($sessionsContent -and $sessionsContent -notmatch [regex]::Escape("`"$sessionId`"")) {
                Remove-Item $f.FullName -Force
                $orphans++
            }
        }
        if ($orphans -gt 0) {
            Ok "Cleaned $orphans orphan session file(s)"
            $fixes++
        }
    }

    # -- Log rotation hint --
    $gwLog = Join-Path $OPENCLAW_CONFIG_DIR "logs\gateway.log"
    if (Test-Path $gwLog) {
        $logSize = (Get-Item $gwLog).Length
        if ($logSize -gt 52428800) {
            $sizeMB = [math]::Floor($logSize / 1048576)
            Warn "gateway.log is ${sizeMB}MB - consider truncating"
        }
    }

    # -- Harden file permissions --
    if (Test-Path $OPENCLAW_CONFIG_DIR) {
        try {
            $acl = Get-Acl $OPENCLAW_CONFIG_DIR
            $needsFix = -not $acl.AreAccessRulesProtected
            if (-not $needsFix) {
                # Check if any rule grants access to someone other than the current user
                foreach ($rule in $acl.Access) {
                    if ($rule.IdentityReference.Value -notmatch [regex]::Escape($env:USERNAME) -and
                        $rule.IdentityReference.Value -ne 'NT AUTHORITY\SYSTEM' -and
                        $rule.IdentityReference.Value -ne 'BUILTIN\Administrators') {
                        $needsFix = $true; break
                    }
                }
            }
            if ($needsFix) {
                $acl.SetAccessRuleProtection($true, $false)
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.SetAccessRule($rule)
                Set-Acl $OPENCLAW_CONFIG_DIR $acl -ErrorAction SilentlyContinue
                Ok "File permissions: ~/.openclaw restricted to current user"
                $fixes++
            }
        } catch { Warn "Could not set permissions on $OPENCLAW_CONFIG_DIR" }
    }
    Harden-ConfigPermissions

    # -- Verify gateway.auth.mode --
    $authMode = Config-Read "gateway.auth.mode"
    if ($authMode -and $authMode -ne "token") {
        $env:OC_FILE = $OPENCLAW_CONFIG
        try {
            & node -e '
                const fs = require("fs");
                const f = process.env.OC_FILE;
                const config = JSON.parse(fs.readFileSync(f, "utf8"));
                if (!config.gateway) config.gateway = {};
                if (!config.gateway.auth) config.gateway.auth = {};
                config.gateway.auth.mode = "token";
                const tmp = f + ".tmp." + process.pid;
                fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + "\n");
                fs.renameSync(tmp, f);
            ' 2>$null
            Ok "gateway.auth.mode: set to token"
            $fixes++
        } catch { }
    }

    # -- Verify gateway listens on localhost only --
    $gwHost = Config-Read "gateway.host"
    if ($gwHost -and $gwHost -ne "127.0.0.1" -and $gwHost -ne "localhost") {
        Warn "gateway.host is '$gwHost' — consider restricting to 127.0.0.1"
    }

    # -- Harden permissions on backup files --
    Get-ChildItem "$OPENCLAW_CONFIG.bak.*" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $acl = Get-Acl $_.FullName
            if (-not $acl.AreAccessRulesProtected) {
                $acl.SetAccessRuleProtection($true, $false)
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $env:USERNAME, "FullControl", "Allow")
                $acl.SetAccessRule($rule)
                Set-Acl $_.FullName $acl -ErrorAction SilentlyContinue
            }
        } catch { }
    }

    if ($fixes -eq 0) { Ok "No issues found" }
    else { Ok "$fixes issue(s) fixed" }
}

# ======================================================================
#  PHASE 8: Summary
# ======================================================================
function Phase8-Summary {
    Phase 8 "Setup complete"

    $ocVersion = & openclaw --version 2>$null
    if (-not $ocVersion) { $ocVersion = "unknown" }

    # Detect active channels
    $channels = ""
    foreach ($ch in @('feishu','telegram','slack','discord')) {
        $chEnabled = Config-Read "channels.$ch.enabled"
        if ($chEnabled -eq "true") { $channels += "$ch " }
    }

    $gwPort = Config-Read "gateway.port"
    if (-not $gwPort) { $gwPort = "18789" }

    Write-Host ""
    Write-Host "  +==========================================+" -ForegroundColor Green
    Write-Host "  |  " -ForegroundColor Green -NoNewline
    Write-Host "OpenClaw is ready!" -ForegroundColor Green -NoNewline
    Write-Host "                     |" -ForegroundColor Green
    Write-Host "  +==========================================+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Version:   $ocVersion" -ForegroundColor White
    Write-Host "  Config:    $OPENCLAW_CONFIG"
    Write-Host "  Channels:  $(if ($channels) { $channels.Trim() } else { 'none' })"
    Write-Host "  Gateway:   ws://127.0.0.1:$gwPort"
    Write-Host ""

    Divider
    Write-Host "  Quick start:"
    Write-Host ""
    Write-Host "    openclaw status              " -ForegroundColor Cyan -NoNewline; Write-Host "# Health check"
    Write-Host "    openclaw logs --follow       " -ForegroundColor Cyan -NoNewline; Write-Host "# Live logs"
    Write-Host "    openclaw tui                 " -ForegroundColor Cyan -NoNewline; Write-Host "# Terminal chat UI"
    Write-Host "    openclaw skills list         " -ForegroundColor Cyan -NoNewline; Write-Host "# Available skills"
    Write-Host "    openclaw cron list           " -ForegroundColor Cyan -NoNewline; Write-Host "# Scheduled jobs"
    Write-Host ""

    if ($channels) {
        Divider
        Write-Host "  Messaging:"
        Write-Host ""
        $firstCh = ($channels.Trim() -split ' ')[0]
        Write-Host "    openclaw message send --channel $firstCh \" -ForegroundColor Cyan
        Write-Host "      --target <id> --message `"hello`"" -ForegroundColor Cyan
        Write-Host ""
    }

    Divider
    Write-Host "  Documentation:  https://docs.openclaw.ai"
    Write-Host ""

    if ($script:NeedTokenFix) {
        Write-Host "  Important: " -ForegroundColor Yellow -NoNewline
        Write-Host "Open a new terminal to activate the gateway token."
        Write-Host ""
    }

    # Dashboard URL
    $dashboardUrl = "http://127.0.0.1:$gwPort/"
    $dashboardOpenUrl = $dashboardUrl
    if ($script:GatewayToken) {
        $dashboardOpenUrl = "${dashboardUrl}#token=$($script:GatewayToken)"
    }
    Divider
    Write-Host ""
    Write-Host "  > Dashboard:  " -ForegroundColor Green -NoNewline
    Write-Host $dashboardOpenUrl -ForegroundColor Cyan
    Write-Host ""

    # Auto-open in browser (interactive mode only)
    if (-not $script:NonInteractive) {
        try { Start-Process $dashboardOpenUrl; Ok "Dashboard opened in browser" } catch { }
    }
}

# ======================================================================
#  Uninstall
# ======================================================================
function Do-Uninstall {
    Show-Banner
    Write-Host "  OpenClaw Uninstaller" -ForegroundColor Red
    Write-Host ""

    # -- 1. Stop gateway --
    Info "Stopping gateway..."
    try { & openclaw gateway stop 2>$null } catch { }
    try { & openclaw gateway uninstall 2>$null } catch { }

    # Remove scheduled task
    $task = Get-ScheduledTask -TaskName "OpenClawGateway" -ErrorAction SilentlyContinue
    if ($task) {
        Stop-ScheduledTask -TaskName "OpenClawGateway" -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName "OpenClawGateway" -Confirm:$false -ErrorAction SilentlyContinue
        Ok "Scheduled task removed"
    }

    # Kill background gateway processes (use CimInstance for PS 5.1 compat)
    Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'openclaw.*gateway' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Ok "Gateway processes stopped"

    # -- 2. Uninstall npm package --
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        $ocVer = & openclaw --version 2>$null
        if (-not $ocVer) { $ocVer = "unknown" }
        Info "Uninstalling openclaw ($ocVer)..."
        & npm uninstall -g openclaw 2>&1 | Select-Object -Last 1
        Refresh-Path
        if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
            Ok "openclaw npm package removed"
        } else {
            Warn "npm uninstall may have failed, try manually: npm uninstall -g openclaw"
        }
    } else {
        Ok "openclaw not installed (skipped)"
    }

    # -- 3. Config & data --
    if (Test-Path $OPENCLAW_CONFIG_DIR) {
        Write-Host ""
        Write-Host "  Config directory: $OPENCLAW_CONFIG_DIR" -ForegroundColor White

        if (Test-Path $OPENCLAW_CONFIG) {
            $channelsConfigured = ""
            foreach ($ch in @('feishu','telegram','slack','discord')) {
                $chVal = Config-Read "channels.$ch.enabled"
                if ($chVal -eq "true") { $channelsConfigured += "$ch " }
            }
            if ($channelsConfigured) { Warn "Active channels found: $channelsConfigured" }
        }
        Write-Host ""

        if (Confirm "Delete config directory (~/.openclaw)?") {
            $backupZip = Join-Path $env:USERPROFILE "openclaw-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
            Info "Creating backup: $backupZip"
            try {
                Compress-Archive -Path $OPENCLAW_CONFIG_DIR -DestinationPath $backupZip -Force
                Ok "Backup saved: $backupZip"
            } catch {
                Warn "Backup failed, proceeding anyway"
            }

            Remove-Item $OPENCLAW_CONFIG_DIR -Recurse -Force
            Ok "Config directory deleted"
        } else {
            Info "Config directory kept: $OPENCLAW_CONFIG_DIR"
        }
    }

    # -- 4. Profile cleanup --
    # Only remove lines that exactly match what this installer writes.
    # This avoids accidentally breaking complex profiles where the keyword
    # appears inside comments, here-strings, or multi-line expressions.
    Info "Cleaning PowerShell profile..."
    $cleaned = $false
    if ((Test-Path $PROFILE) -and (Get-Content $PROFILE -ErrorAction SilentlyContinue | Select-String 'OPENCLAW_GATEWAY_TOKEN')) {
        $content = Get-Content $PROFILE | Where-Object {
            # Match only the exact patterns this installer writes
            $_ -notmatch '^\s*\$env:OPENCLAW_GATEWAY_TOKEN\s*=' -and
            $_ -notmatch '^\s*# OpenClaw Gateway Token\s*$'
        }
        $content | Set-Content $PROFILE
        Ok "Cleaned: $PROFILE"
        $cleaned = $true
    }

    # Remove persistent env var
    $envToken = [Environment]::GetEnvironmentVariable('OPENCLAW_GATEWAY_TOKEN', 'User')
    if ($envToken) {
        [Environment]::SetEnvironmentVariable('OPENCLAW_GATEWAY_TOKEN', $null, 'User')
        Ok "Removed OPENCLAW_GATEWAY_TOKEN environment variable"
        $cleaned = $true
    }

    if (-not $cleaned) { Ok "No token entries found" }

    # -- 5. Remove install9 command --
    if (Test-Path $INSTALL9_DIR) {
        Remove-Item $INSTALL9_DIR -Recurse -Force
        Ok "Removed: $INSTALL9_DIR"
    }
    # Remove from user PATH
    $userPathVal = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPathVal -match [regex]::Escape($INSTALL9_DIR)) {
        $newPath = ($userPathVal -split ';' | Where-Object { $_ -ne $INSTALL9_DIR }) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Ok "Removed install9 from PATH"
    }

    # -- 6. Temp files --
    $tempOc = Join-Path $env:TEMP "openclaw"
    if (Test-Path $tempOc) {
        Remove-Item $tempOc -Recurse -Force
        Ok "Cleaned temp files"
    }

    # -- Done --
    Write-Host ""
    Divider
    Write-Host "  Uninstall complete." -ForegroundColor Green
    Write-Host ""
    if (Get-Command fnm -ErrorAction SilentlyContinue) {
        Info "fnm and Node.js were kept (shared dependency)."
        Info "To remove fnm: winget uninstall Schniz.fnm"
    }
    Write-Host ""
}

# ======================================================================
#  Self-install: register as local command
# ======================================================================
function Self-Install {
    # Determine script source
    $scriptSource = ""
    if ($MyInvocation.ScriptName) {
        $scriptSource = $MyInvocation.ScriptName
    } elseif ($PSCommandPath) {
        $scriptSource = $PSCommandPath
    }

    # Skip if already installed and up to date
    if (Test-Path $INSTALL9_BIN) {
        if ($scriptSource -and (Resolve-Path $scriptSource -ErrorAction SilentlyContinue).Path -eq
            (Resolve-Path $INSTALL9_BIN -ErrorAction SilentlyContinue).Path) {
            return  # Already running from installed location
        }
        $installedVer = (Select-String -Path $INSTALL9_BIN -Pattern '^\$INSTALLER_VERSION\s*=\s*"(.+)"' -ErrorAction SilentlyContinue |
            Select-Object -First 1).Matches.Groups[1].Value
        if ($installedVer -eq $INSTALLER_VERSION) { return }
    }

    # Create install directory
    if (-not (Test-Path $INSTALL9_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL9_DIR -Force | Out-Null
    }

    # Copy or download the script
    if ($scriptSource -and (Test-Path $scriptSource)) {
        Copy-Item $scriptSource $INSTALL9_BIN -Force
    } else {
        # Piped via irm|iex — download a clean copy
        Invoke-WebRequest -Uri $INSTALL9_URL -OutFile $INSTALL9_BIN -UseBasicParsing -TimeoutSec 60
    }

    # Create a .cmd wrapper so "install9" works from cmd.exe and PowerShell alike
    @"
@echo off
powershell -ExecutionPolicy Bypass -File "$INSTALL9_BIN" %*
"@ | Set-Content $INSTALL9_CMD -Encoding ASCII

    # Add to user PATH if not already there
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notmatch [regex]::Escape($INSTALL9_DIR)) {
        [Environment]::SetEnvironmentVariable('Path', "$INSTALL9_DIR;$userPath", 'User')
        $env:Path = "$INSTALL9_DIR;$env:Path"
    }

    Ok "install9 command installed: $INSTALL9_DIR"
    Info "Run 'install9 --help' from any terminal"
}

function Do-SelfUpdate {
    Show-Banner
    Info "Updating install9..."

    $tmpFile = Join-Path $env:TEMP "install9-update-$([guid]::NewGuid().ToString('N')).ps1"
    try {
        Invoke-WebRequest -Uri $INSTALL9_URL -OutFile $tmpFile -UseBasicParsing -TimeoutSec 60
    } catch {
        Fail "Failed to download update from $INSTALL9_URL"
    }

    $remoteVer = (Select-String -Path $tmpFile -Pattern '^\$INSTALLER_VERSION\s*=\s*"(.+)"' -ErrorAction SilentlyContinue |
        Select-Object -First 1).Matches.Groups[1].Value

    if (-not $remoteVer) {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        Fail "Downloaded file does not look like a valid installer"
    }

    # Basic content validation
    $content = Get-Content $tmpFile -Raw
    if ($content.Length -lt 1000 -or $content -notmatch 'function Phase1-Detect' -or $content -notmatch 'function Main') {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        Fail "Downloaded file does not look like a valid installer"
    }

    if ($remoteVer -eq $INSTALLER_VERSION) {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        Ok "Already on latest version ($INSTALLER_VERSION)"
        exit 0
    }

    # Install updated version
    if (-not (Test-Path $INSTALL9_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL9_DIR -Force | Out-Null
    }
    Move-Item $tmpFile $INSTALL9_BIN -Force

    # Recreate .cmd wrapper
    @"
@echo off
powershell -ExecutionPolicy Bypass -File "$INSTALL9_BIN" %*
"@ | Set-Content $INSTALL9_CMD -Encoding ASCII

    Ok "Updated: v$INSTALLER_VERSION -> v$remoteVer"
    Info "Run 'install9 --version' to verify"
    exit 0
}

# ======================================================================
#  Main
# ======================================================================
function Main {
    # Parse args: support both direct invocation and irm|iex via env var
    $argList = $args
    if ($env:OPENCLAW_INSTALL_ARGS) {
        $argList = $env:OPENCLAW_INSTALL_ARGS -split '\s+'
        Remove-Item env:OPENCLAW_INSTALL_ARGS -ErrorAction SilentlyContinue
    }
    if ($argList) { Parse-Args $argList }

    if ($script:ArgUninstall) { Do-Uninstall; return }
    if ($script:ArgSelfUpdate) { Do-SelfUpdate }

    Show-Banner
    Phase1-Detect
    Phase2-Deps
    Phase3-Install
    Phase4-Init
    Phase5-Gateway
    Phase6-Channel
    Phase7-Security
    Self-Install
    Phase8-Summary
}

# Check execution policy — provide clear guidance if scripts are blocked
$execPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($execPolicy -eq 'Restricted') {
    Write-Host ""
    Write-Host "  PowerShell execution policy is set to 'Restricted'." -ForegroundColor Yellow
    Write-Host "  Scripts cannot run under this policy." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To fix, run one of these commands:" -ForegroundColor White
    Write-Host "    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
    Write-Host "    powershell -ExecutionPolicy Bypass -File .\install.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Or use the one-liner (bypasses policy automatically):" -ForegroundColor White
    Write-Host "    irm https://install9.ai/openclaw-win | iex" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

try {
    Main @args
} catch {
    Write-Host ""
    Write-Host "  Installation interrupted: $_" -ForegroundColor Red
    Write-Host "  Config backups: $OPENCLAW_CONFIG.bak.*"
    Write-Host "  Logs: $OPENCLAW_CONFIG_DIR\logs\"
    Write-Host "  Re-run this script to continue from where it stopped."
    Write-Host ""
    exit 1
}
