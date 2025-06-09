#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ———————— PROMPT FOR INPUT ————————
read -rp "Username to install pyenv for: " USERNAME
read -rp "Python version to install (e.g. 3.11.0): " PYTHON_VERSION

# ———————— VALIDATE ————————
if ! id "$USERNAME" &>/dev/null; then
  echo "❌ User '$USERNAME' does not exist." >&2
  exit 1
fi
USER_HOME="/home/$USERNAME"
PYENV_ROOT="$USER_HOME/.pyenv"

# ————— CLEAN OLD INSTALL ——————
if [ -d "$PYENV_ROOT" ]; then
  echo "🗑  Removing old pyenv at $PYENV_ROOT"
  rm -rf "$PYENV_ROOT"
fi

# ————— INSTALL BUILD DEPS ——————
echo "🔧 Installing build dependencies…"
apt-get update
apt-get install -y --no-install-recommends \
  make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev \
  wget curl llvm libncurses-dev xz-utils tk-dev \
  libffi-dev liblzma-dev

# ————— INSTALL pyenv ——————
echo "🚀 Installing pyenv into $PYENV_ROOT…"
sudo -u "$USERNAME" -H env HOME="$USER_HOME" bash -lc '
  cd "$HOME" &&
  curl https://pyenv.run | bash
'

# ——— CONFIGURE ~/.bashrc ————
echo "⚙️  Appending pyenv init to ~/.bashrc…"
sudo -u "$USERNAME" -H bash -lc '
  cat >> "$HOME/.bashrc" << "EOF"

# >>> pyenv configuration (added by install_pyenv.sh) >>>
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
# <<< end pyenv configuration <<<
EOF
'

# ——— ENSURE LOGIN SHELL LOADS ~/.bashrc ————
echo "🔄 Ensuring ~/.profile sources ~/.bashrc…"
sudo -u "$USERNAME" -H bash -lc '
  grep -qxF "if [ -f \"$HOME/.bashrc\" ]; then source \"$HOME/.bashrc\"; fi" "$HOME/.profile" \
    || cat >> "$HOME/.profile" << "EOF"

# Source BashRC for login shells
if [ -f "$HOME/.bashrc" ]; then
  source "$HOME/.bashrc"
fi
EOF
'

# ——— INSTALL & ACTIVATE PYTHON ————
echo "🐍 Installing Python $PYTHON_VERSION via pyenv…"
sudo -u "$USERNAME" -H env \
  HOME="$USER_HOME" \
  PYENV_ROOT="$PYENV_ROOT" \
  PATH="$PYENV_ROOT/bin:$PATH" \
  bash -lc "
    cd \"\$HOME\" &&
    \"$PYENV_ROOT/bin/pyenv\" install --skip-existing $PYTHON_VERSION &&
    \"$PYENV_ROOT/bin/pyenv\" global $PYTHON_VERSION
  "

echo
echo "✅ Done! pyenv + Python $PYTHON_VERSION installed for '$USERNAME'."
echo
echo "Next steps:"
echo "  1. Switch to that user:   su - $USERNAME"
echo "  2. Verify installation:   python --version"
echo "  3. If you ever see a load-path warning again, run: source ~/.bashrc"
