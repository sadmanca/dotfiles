#!/bin/bash

# 1. Install System Dependencies (Ripgrep)
sudo apt-get update
sudo apt-get install -y ripgrep

# 2. Install Bun
curl -fsSL https://bun.sh/install | bash

# 3. Install OpenCode and Claude Code globally
sudo npm install -g opencode-ai @anthropic-ai/claude-code

# 4. Configure Git authentication for ANY repo
# (This activates automatically if you set the GLOBAL_GIT_PAT secret)
if [ -n "$GLOBAL_GIT_PAT" ]; then
  # Replaces standard https git URLs with authenticated ones
  git config --global url."https://${GLOBAL_GIT_PAT}@github.com/".insteadOf "https://github.com/"
fi

# 5. Inject aliases and environment variables into shell profiles
inject_config() {
cat << 'EOF' >> "$1"

# Claude Code default permissions and sandbox vars
export CLAUDE_CODE_DANGEROUSLY_SKIP_PERMISSIONS=1
export SANDBOX=1

# Ensure the standard claude command also bypasses permissions
alias claude="claude --dangerously-skip-permissions"

# Wrapper to route Claude Code through DeepSeek API
claude-ds() {
  export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY}"
  
  # Set default models to the July 31, 2026 release of V4 Flash
  # (V4-Flash-0731 has significantly upgraded agent capabilities)
  export ANTHROPIC_MODEL="deepseek-v4-flash-0731"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-flash-0731"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-flash-0731"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash-0731"
  export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash-0731"
  
  export CLAUDE_CODE_EFFORT_LEVEL="max"
  
  # Run Claude with skip permissions and any passed arguments
  command claude --dangerously-skip-permissions "$@"
}

# Optional wrapper for Pro if you need heavier reasoning
claude-ds-pro() {
  export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY}"
  
  export ANTHROPIC_MODEL="deepseek-v4-pro"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-pro"
  export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-pro"
  
  export CLAUDE_CODE_EFFORT_LEVEL="max"
  
  command claude --dangerously-skip-permissions "$@"
}
EOF
}

# Apply to common shell config files used in Codespaces
if [ -f "$HOME/.bashrc" ]; then inject_config "$HOME/.bashrc"; fi
if [ -f "$HOME/.zshrc" ]; then inject_config "$HOME/.zshrc"; fi