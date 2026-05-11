#!/bin/bash
# codex-deepseek-setup: 一键配置 Codex + DeepSeek
set -e

PROXY_DIR="$HOME/.codex-proxy"
BIN_DIR="$PROXY_DIR/bin"
BIN="$BIN_DIR/cli-proxy-api"
CONFIG="$PROXY_DIR/config.yaml"
PATCH="$PROXY_DIR/deepseek-anthropic-fix.patch"

# 下载patch
if [[ ! -f "$PATCH" ]]; then
  mkdir -p "$PROXY_DIR"
  curl -sL "https://raw.githubusercontent.com/hanger-source/codex-deepseek/main/deepseek-anthropic-fix.patch" -o "$PATCH"
fi
PORT=15721

echo "=== Codex + DeepSeek 一键配置 ==="
echo ""

# 1. 编译 CLIProxyAPI（带patch）
if [[ ! -x "$BIN" ]]; then
  echo "▶ 编译 CLIProxyAPI..."
  if ! command -v go &>/dev/null; then
    echo "错误: 需要安装 Go (https://go.dev/dl/)"; exit 1
  fi
  mkdir -p "$BIN_DIR"
  BUILD_DIR="/tmp/CLIProxyAPI-build"
  rm -rf "$BUILD_DIR"
  git clone --depth 1 https://github.com/router-for-me/CLIProxyAPI.git "$BUILD_DIR"
  cd "$BUILD_DIR"
  if [[ -f "$PATCH" ]]; then
    git apply "$PATCH"
    echo "  ✓ 已应用 deepseek-anthropic-fix.patch"
  fi
  go build -o "$BIN" ./cmd/server
  cd - >/dev/null
  rm -rf "$BUILD_DIR"
  echo "  ✓ 已编译到 $BIN"
else
  echo "▶ CLIProxyAPI 已存在，跳过编译（删除 $BIN 可重新编译）"
fi

# 2. 交互式填写配置
echo ""
read -p "▶ DeepSeek API Key: " DEEPSEEK_KEY
if [[ -z "$DEEPSEEK_KEY" ]]; then
  echo "错误: API Key 不能为空"; exit 1
fi

echo "▶ 选择模型:"
echo "  1) deepseek-v4-pro + deepseek-v4-flash（默认）"
echo "  2) 仅 deepseek-v4-pro"
echo "  3) 仅 deepseek-v4-flash"
read -p "  选择 [1]: " MODEL_CHOICE
MODEL_CHOICE="${MODEL_CHOICE:-1}"

case "$MODEL_CHOICE" in
  1) MODELS_YAML='    models:
      - name: "deepseek-v4-pro"
        alias: "deepseek/deepseek-v4-pro"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-flash"
        alias: "deepseek/deepseek-v4-flash"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-pro"
        alias: "gpt-5.5"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-pro"
        alias: "gpt-5.4"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-flash"
        alias: "gpt-5.4-mini"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-pro"
        alias: "o3"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-flash"
        alias: "o4-mini"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]'
     DEFAULT_MODEL="deepseek/deepseek-v4-pro" ;;
  2) MODELS_YAML='    models:
      - name: "deepseek-v4-pro"
        alias: "deepseek/deepseek-v4-pro"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-pro"
        alias: "gpt-5.5"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-pro"
        alias: "gpt-5.4"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-pro"
        alias: "o3"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]'
     DEFAULT_MODEL="deepseek/deepseek-v4-pro" ;;
  3) MODELS_YAML='    models:
      - name: "deepseek-v4-flash"
        alias: "deepseek/deepseek-v4-flash"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-flash"
        alias: "gpt-5.4-mini"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]
      - name: "deepseek-v4-flash"
        alias: "o4-mini"
        thinking:
          levels: ["low", "medium", "high", "xhigh"]'
     DEFAULT_MODEL="deepseek/deepseek-v4-flash" ;;
  *) echo "无效选择"; exit 1 ;;
esac

echo "▶ 协议模式:"
echo "  1) Anthropic 兼容（默认，支持 web search）"
echo "  2) OpenAI 兼容（仅对话+工具）"
read -p "  选择 [1]: " PROTOCOL_CHOICE
PROTOCOL_CHOICE="${PROTOCOL_CHOICE:-1}"

read -p "▶ 代理地址（留空则直连）: " PROXY_URL
read -p "▶ 监听端口 [$PORT]: " INPUT_PORT
PORT="${INPUT_PORT:-$PORT}"

# 3. 生成配置
mkdir -p "$PROXY_DIR/auth"
if [[ "$PROTOCOL_CHOICE" == "2" ]]; then
cat > "$CONFIG" << EOF
port: $PORT
host: "127.0.0.1"
auth-dir: "$PROXY_DIR/auth"
api-keys: []
$([ -n "$PROXY_URL" ] && echo "proxy-url: \"$PROXY_URL\"")
openai-compatibility:
  - name: "deepseek"
    base-url: "https://api.deepseek.com/v1"
    api-key-entries:
      - api-key: "$DEEPSEEK_KEY"
$MODELS_YAML
EOF
else
cat > "$CONFIG" << EOF
port: $PORT
host: "127.0.0.1"
auth-dir: "$PROXY_DIR/auth"
api-keys: []
$([ -n "$PROXY_URL" ] && echo "proxy-url: \"$PROXY_URL\"")
claude-api-key:
  - api-key: "$DEEPSEEK_KEY"
    base-url: "https://api.deepseek.com/anthropic"
$MODELS_YAML
EOF
fi
echo "  ✓ 配置已写入 $CONFIG"

# 4. 配置 Codex
mkdir -p "$HOME/.codex"
cat > "$HOME/.codex/config.toml" << EOF
model_provider = "deepseek-proxy"
model = "$DEFAULT_MODEL"

[model_providers.deepseek-proxy]
name = "deepseek-proxy"
base_url = "http://127.0.0.1:$PORT/v1"
wire_api = "responses"

[projects."/Users/$(whoami)"]
trust_level = "trusted"
EOF
echo "  ✓ Codex 配置已更新"

# 5. 写管理脚本
cat > "$PROXY_DIR/codex-proxy" << 'SCRIPT'
#!/bin/bash
DIR="$HOME/.codex-proxy"
BIN="$DIR/bin/cli-proxy-api"
CONFIG="$DIR/config.yaml"
LOG="$DIR/proxy.log"
PID_FILE="$DIR/proxy.pid"

case "${1:-start}" in
  start)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "已在运行 (pid $(cat "$PID_FILE"))"; exit 0
    fi
    "$BIN" -config "$CONFIG" > "$LOG" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1
    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "✓ 已启动 :$(grep '^port:' "$CONFIG" | awk '{print $2}') (pid $(cat "$PID_FILE"))"
    else
      echo "✗ 启动失败"; tail -5 "$LOG"; exit 1
    fi ;;
  stop)
    [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" 2>/dev/null && rm -f "$PID_FILE" && echo "已停止" || echo "未运行" ;;
  restart) "$0" stop; sleep 1; "$0" start ;;
  status)
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null && echo "运行中 (pid $(cat "$PID_FILE"))" || echo "未运行" ;;
  log) tail -30 "$LOG" ;;
  *) echo "用法: codex-proxy {start|stop|restart|status|log}" ;;
esac
SCRIPT
chmod +x "$PROXY_DIR/codex-proxy"

# 6. 链接到PATH
mkdir -p "$HOME/.local/bin"
ln -sf "$PROXY_DIR/codex-proxy" "$HOME/.local/bin/codex-proxy"

# 7. 启动
pkill -f "cli-proxy-api -config" 2>/dev/null
sleep 1
"$PROXY_DIR/codex-proxy" start

echo ""
echo "=== 配置完成 ==="
echo "  管理命令: codex-proxy {start|stop|restart|status|log}"
echo "  配置文件: $CONFIG"
echo "  默认模型: $DEFAULT_MODEL"
echo "  打开 Codex 即可使用"


