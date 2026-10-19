#!/bin/bash

# 1. Install system dependencies
sudo apt-get update
sudo apt-get install -y ripgrep micro fzf bat fd-find

# zoxide and eza are only packaged on newer Ubuntu releases, so fall back to
# upstream release binaries when apt cannot provide them.
sudo apt-get install -y zoxide >/dev/null 2>&1 || true
sudo apt-get install -y eza >/dev/null 2>&1 || true

if ! command -v zoxide >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
    | sh -s -- --bin-dir /usr/local/bin
fi

if ! command -v eza >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64) eza_arch="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) eza_arch="aarch64-unknown-linux-gnu" ;;
    *) eza_arch="" ;;
  esac
  if [ -n "$eza_arch" ]; then
    curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_${eza_arch}.tar.gz" \
      | sudo tar xzf - -C /usr/local/bin
  fi
fi

# 2. Install oh-my-bash
if [ ! -d "$HOME/.oh-my-bash" ]; then
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended
fi

# 3. Install Bun
curl -fsSL https://bun.sh/install | bash

# 4. Install OpenCode and Claude Code globally
sudo npm install -g opencode-ai @anthropic-ai/claude-code

# 5. Configure Git authentication for ANY repo
# (This activates automatically if you set the GLOBAL_GIT_PAT secret)
if [ -n "$GLOBAL_GIT_PAT" ]; then
  # Replaces standard https git URLs with authenticated ones
  git config --global url."https://${GLOBAL_GIT_PAT}@github.com/".insteadOf "https://github.com/"
fi

# 6. Inject aliases and environment variables into shell profiles
inject_config() {
  local rc="$1"
  [ -f "$rc" ] || return 0

  # Skip if a previous run already injected the block
  if grep -q '# >>> dotfiles >>>' "$rc" || grep -q 'claude-ds()' "$rc"; then
    return 0
  fi

cat << 'EOF' >> "$rc"

# >>> dotfiles >>>
# Claude Code default permissions and sandbox vars
export CLAUDE_CODE_DANGEROUSLY_SKIP_PERMISSIONS=1
export SANDBOX=1

# Ensure the standard claude command also bypasses permissions
alias claude="claude --dangerously-skip-permissions"

# Wrapper to route Claude Code through DeepSeek API
claude-ds() {
  export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY}"

  # Use the model name supported by the DeepSeek API
  export ANTHROPIC_MODEL="deepseek-flash"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-flash"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-flash"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-flash"
  export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-flash"

  export CLAUDE_CODE_EFFORT_LEVEL="max"

  # Run Claude with skip permissions and any passed arguments
  command claude --dangerously-skip-permissions "$@"
}

# Modern CLI aliases (Debian renames the bat and fd binaries)
if command -v batcat >/dev/null 2>&1; then alias bat=batcat; fi
if command -v fdfind >/dev/null 2>&1; then alias fd=fdfind; fi

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -alF --icons=auto --group-directories-first --git'
  alias la='eza -a --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto'
fi

# Shell integrations
if command -v zoxide >/dev/null 2>&1; then
  if [ -n "$BASH_VERSION" ]; then eval "$(zoxide init bash)"; fi
  if [ -n "$ZSH_VERSION" ]; then eval "$(zoxide init zsh)"; fi
fi

if command -v fzf >/dev/null 2>&1; then
  if [ -n "$BASH_VERSION" ]; then
    if fzf --bash >/dev/null 2>&1; then
      eval "$(fzf --bash)"
    elif [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
      . /usr/share/doc/fzf/examples/key-bindings.bash
    fi
  fi
  if [ -n "$ZSH_VERSION" ]; then
    if fzf --zsh >/dev/null 2>&1; then
      eval "$(fzf --zsh)"
    elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
      . /usr/share/doc/fzf/examples/key-bindings.zsh
    fi
  fi
fi
# <<< dotfiles <<<
EOF
}

# Apply to common shell config files used in Codespaces
if [ -f "$HOME/.bashrc" ]; then inject_config "$HOME/.bashrc"; fi
if [ -f "$HOME/.zshrc" ]; then inject_config "$HOME/.zshrc"; fi
