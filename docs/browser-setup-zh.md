# OpenClaw 浏览器 Attach-only 模式配置指南

> 通过 Chrome DevTools Protocol (CDP) 将 OpenClaw 连接到已有的 Chrome 实例。

## 前置条件

- OpenClaw 已安装且 Gateway 正在运行
- 已安装 Google Chrome

## 快速配置

### 1. 配置 OpenClaw

安装器可一键完成（`install9 --browser`），也可手动配置：

```bash
openclaw config set browser.enabled true
openclaw config set browser.attachOnly true
openclaw config set browser.cdpUrl "http://localhost:9222"
openclaw config set browser.evaluateEnabled true
```

### 2. 以远程调试模式启动 Chrome

macOS:
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

> **注意：** 如果 Chrome 已在运行，需要先关闭所有 Chrome 窗口，再用上述命令重新启动。

### 3. 安装 Chrome 扩展

```bash
openclaw browser extension install
```

扩展会被复制到 `~/.openclaw/browser/chrome-extension/`。

### 4. 在 Chrome 中加载扩展

1. 地址栏输入 `chrome://extensions` 并回车
2. 打开右上角 **开发者模式** 开关
3. 点击 **加载已解压的扩展程序**
4. 选择目录 `~/.openclaw/browser/chrome-extension/`
5. 将 **OpenClaw Browser Relay** 固定到工具栏

### 5. 配置扩展

右键点击扩展图标 → **选项**（Options），填写：

- **Port**：`18792`（默认 Relay 端口，保持不变）
- **Gateway token**：粘贴你的 Gateway 令牌

获取令牌：
```bash
openclaw config get gateway.auth.token
```

点击 **Save** 保存。

### 6. 激活连接

在任意标签页上点击工具栏的 **OpenClaw Browser Relay** 图标，徽章应显示为 **ON**。

## 验证

```bash
# 检查浏览器状态
openclaw browser status

# 列出已打开的标签页（不应为空）
openclaw browser tabs

# 测试导航
openclaw browser navigate https://www.google.com

# 截图
openclaw browser screenshot
```

## 常见问题

### `tabs: []`（未检测到标签页）

1. 确认 Chrome 已以 `--remote-debugging-port=9222` 启动：
   ```bash
   curl -s http://localhost:9222/json/version
   ```
2. 检查扩展徽章 — 应为 **ON**，而非红色 **!**
3. 确认扩展 Options 中的 Gateway token 与配置一致
4. 重启 Gateway：
   ```bash
   openclaw gateway restart
   ```

### `browser.cdpUrl must be http(s), got: ws`

CDP URL 必须以 `http://` 开头，不能用 `ws://`：
```bash
openclaw config set browser.cdpUrl "http://localhost:9222"
openclaw gateway restart
```

### 扩展图标显示红色 `!`

说明 Relay 服务不可达，请检查：
- Gateway 是否运行：`openclaw gateway status`
- 端口 18792 是否可访问：`curl -s http://127.0.0.1:18792/`

## 架构

```
Chrome (端口 9222)  <--CDP-->  OpenClaw Gateway (端口 18789)
                                       |
                               Relay Server (端口 18792)
                                       |
                              Chrome 扩展 (浏览器内)
```

扩展充当桥梁：注入浏览器标签页，与 OpenClaw Relay 服务通信，Relay 连接 Gateway，Gateway 通过 CDP 控制 Chrome。
