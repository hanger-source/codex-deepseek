# Codex + DeepSeek

让 OpenAI Codex App/CLI 使用 DeepSeek V4 Pro/Flash，通过 Anthropic 兼容协议。

## 一键安装

```bash
bash <(curl -sL https://raw.githubusercontent.com/hanger-source/codex-deepseek/main/setup.sh)
```

## 功能

- DeepSeek V4 Pro / Flash 模型支持
- Thinking/Reasoning 模式
- Web Search（通过 DeepSeek Anthropic 端点）
- Tool Calling（function call）
- Context Cache 友好（messages 前缀稳定）

## 前提

- Go (编译 CLIProxyAPI)
- Git

## 管理

```bash
codex-proxy start    # 启动
codex-proxy stop     # 停止
codex-proxy restart  # 重启
codex-proxy status   # 状态
codex-proxy log      # 日志
```
