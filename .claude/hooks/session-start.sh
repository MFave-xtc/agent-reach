#!/bin/bash
set -euo pipefail

# Only run in Claude Code on the web (remote) sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

export PATH="$HOME/.local/bin:$PATH"

# Persist PATH additions for the rest of the session.
if ! grep -q '.local/bin' "$CLAUDE_ENV_FILE" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

# --- pipx (idempotent) ---
if ! command -v pipx >/dev/null 2>&1; then
  python3 -m pip install --user pipx
  python3 -m pipx ensurepath >/dev/null 2>&1 || true
fi

# --- agent-reach (idempotent) ---
# The GitHub archive zip URL (…/archive/main.zip) 403s through this
# environment's git proxy, so install from a shallow local clone instead.
SRC_DIR="$HOME/.agent-reach/tools/agent-reach-src"
mkdir -p "$HOME/.agent-reach/tools"

if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" pull --ff-only --quiet || true
else
  rm -rf "$SRC_DIR"
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --quiet \
    https://github.com/Panniantong/agent-reach "$SRC_DIR"
fi

if command -v agent-reach >/dev/null 2>&1; then
  python3 -m pipx upgrade agent-reach >/dev/null 2>&1 || \
    python3 -m pipx install --backend pip --force "$SRC_DIR"
else
  python3 -m pipx install --backend pip "$SRC_DIR"
fi

# --- yt-dlp (idempotent) ---
if ! command -v yt-dlp >/dev/null 2>&1; then
  python3 -m pip install --user -U "yt-dlp[default]"
fi

# --- Safe, read-only status check. Never auto-installs system packages;
# the user must explicitly approve `--system` per the install guide. ---
agent-reach install --env=auto || true
