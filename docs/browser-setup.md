# OpenClaw Browser Attach-only Mode Setup

> Connect OpenClaw to an existing Chrome instance via Chrome DevTools Protocol (CDP).

## Prerequisites

- OpenClaw installed and gateway running
- Google Chrome installed

## Quick Setup

### 1. Configure OpenClaw

The installer handles this automatically (`install9 --browser`), or manually:

```bash
openclaw config set browser.enabled true
openclaw config set browser.attachOnly true
openclaw config set browser.cdpUrl "http://localhost:9222"
openclaw config set browser.evaluateEnabled true
```

### 2. Launch Chrome with Remote Debugging

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/openclaw \
  --no-first-run \
  --no-default-browser-check
```

Linux:
```bash
google-chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/openclaw \
  --no-first-run \
  --no-default-browser-check
```

### 3. Install Chrome Extension

```bash
openclaw browser extension install
```

This copies the extension to `~/.openclaw/browser/chrome-extension/`.

### 4. Load Extension in Chrome

1. Navigate to `chrome://extensions`
2. Enable **Developer mode** (top-right toggle)
3. Click **Load unpacked**
4. Select `~/.openclaw/browser/chrome-extension/`
5. Pin **OpenClaw Browser Relay** to the toolbar

### 5. Configure Extension

Open the extension's **Options** page:

- **Port**: `18792` (default relay port, leave as-is)
- **Gateway token**: paste your gateway token

Get your token:
```bash
openclaw config get gateway.auth.token
```

Click **Save**.

### 6. Activate

Click the **OpenClaw Browser Relay** toolbar icon on any tab. The badge should show **ON**.

## Verify

```bash
# Check browser status
openclaw browser status

# List open tabs (should NOT be empty)
openclaw browser tabs

# Test navigation
openclaw browser navigate https://www.google.com

# Take a screenshot
openclaw browser screenshot
```

## Troubleshooting

### `tabs: []` (no tabs detected)

1. Verify Chrome is running with `--remote-debugging-port=9222`:
   ```bash
   curl -s http://localhost:9222/json/version
   ```
2. Check the extension badge — should show **ON**, not red **!**
3. Verify the gateway token matches in the extension Options
4. Restart the gateway:
   ```bash
   openclaw gateway restart
   ```

### `browser.cdpUrl must be http(s), got: ws`

The CDP URL must start with `http://`, not `ws://`:
```bash
openclaw config set browser.cdpUrl "http://localhost:9222"
openclaw gateway restart
```

### Extension shows red `!` badge

The relay server is not reachable. Ensure:
- Gateway is running: `openclaw gateway status`
- Port 18792 is accessible: `curl -s http://127.0.0.1:18792/`

## Architecture

```
Chrome (port 9222)  <--CDP-->  OpenClaw Gateway (port 18789)
                                       |
                               Relay Server (port 18792)
                                       |
                              Chrome Extension (in-browser)
```

The extension acts as a bridge: it injects into browser tabs and communicates with the OpenClaw relay server, which connects to the gateway. The gateway uses CDP to control Chrome.
