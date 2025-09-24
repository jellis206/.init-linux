#!/usr/bin/env bash

# ---------- config ----------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
OHMY_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$OHMY_DIR/custom}"
LOCAL_BIN="$HOME/.local/bin"
ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"

log() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*" >&2; }
die() {
  printf "[ERROR] %s\n" "$*" >&2
  exit 1
}
SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

# ---------- apt base ----------
$SUDO apt-get update -y
$SUDO apt-get install -y \
  zsh git curl unzip fzf zoxide ca-certificates ripgrep \
  libreadline-dev libncurses-dev build-essential clangd

# ---------- default shell ----------
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
  log "Changing default shell to zsh for $USER"
  if ! $SUDO chsh -s /usr/bin/zsh "$USER"; then
    warn "chsh failed (maybe no TTY). Run: chsh -s /usr/bin/zsh"
  fi
fi

# ---------- oh-my-zsh ----------
if [[ ! -d "$OHMY_DIR" ]]; then
  log "Installing Oh My Zsh"
  RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "Oh My Zsh already present"
fi

# ---------- powerlevel10k & plugins ----------
clone_if_missing() {
  local repo="$1" dest="$2"
  [[ -d "$dest" ]] || git clone --depth=1 "https://github.com/${repo}.git" "$dest"
}
clone_if_missing romkatv/powerlevel10k "$ZSH_CUSTOM/themes/powerlevel10k"
clone_if_missing zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
clone_if_missing zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

# ---------- JetBrainsMono Nerd Font ----------
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"
if [[ ! -d "$FONT_DIR" || -z "$(ls -A "$FONT_DIR"/*.ttf 2>/dev/null)" ]]; then
  log "Installing JetBrainsMono Nerd Font"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/font.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
  mkdir -p "$FONT_DIR"
  unzip -q -o "$tmp/font.zip" -d "$FONT_DIR"
  fc-cache -f
  rm -rf "$tmp"
else
  log "JetBrainsMono Nerd Font already installed"
fi

# ---------- asdf ----------
if [ -z "${ASDF_VERSION:-}" ]; then
  log "Fetching latest asdf version from GitHub"
  ASDF_VERSION="$(curl -sL https://api.github.com/repos/asdf-vm/asdf/releases/latest |
    /usr/bin/rg '"tag_name":' | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/')"
  if [ -z "$ASDF_VERSION" ]; then
    warn "Could not find latest asdf version; falling back to 0.18.0"
    ASDF_VERSION="0.18.0"
  else
    log "Latest asdf version is $ASDF_VERSION"
  fi
fi

mkdir -p "$LOCAL_BIN" "$ASDF_DATA_DIR/completions" "$ASDF_DATA_DIR/shims"
ASDF_ARCH=""
case "$(uname -m)" in
aarch64 | arm64) ASDF_ARCH="arm64" ;;
x86_64 | amd64) ASDF_ARCH="amd64" ;;
*) die "Unsupported arch: $(uname -m)" ;;
esac

if ! command -v asdf >/dev/null 2>&1; then
  log "Installing asdf v${ASDF_VERSION} (linux-${ASDF_ARCH})"
  url="https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf-v${ASDF_VERSION}-linux-${ASDF_ARCH}.tar.gz"
  curl -fsSL "$url" -o /tmp/asdf.tar.gz
  tar -xzf /tmp/asdf.tar.gz -C /tmp asdf
  install -m 0755 /tmp/asdf "$LOCAL_BIN/asdf"
  rm -f /tmp/asdf.tar.gz /tmp/asdf
else
  log "asdf already present: $({ asdf --version || true; } 2>/dev/null)"
fi

# asdf zsh completions
if command -v asdf >/dev/null 2>&1; then
  asdf completion zsh >"${ASDF_DATA_DIR}/completions/_asdf" || warn "asdf completion gen failed"
fi

# ---------- asdf plugins & languages ----------
if command -v asdf >/dev/null 2>&1; then
  log "Configuring asdf plugins and languages"

  add_plugin() {
    local name="$1" url="$2"
    if ! asdf plugin list | /usr/bin/rg -q "^$name\$"; then
      log "Adding asdf plugin: $name"
      asdf plugin add "$name" "$url"
    else
      log "Plugin $name already added"
    fi
  }

  # Add plugins
  add_plugin nodejs https://github.com/asdf-vm/asdf-nodejs.git
  add_plugin python https://github.com/asdf-community/asdf-python.git
  add_plugin golang https://github.com/asdf-community/asdf-golang.git
  add_plugin lua https://github.com/Stratus3D/asdf-lua.git

  # Install latest versions & set global
  for lang in nodejs golang; do
    latest="$(asdf latest "$lang" || true)"
    if [[ -n "$latest" ]]; then
      log "Installing $lang $latest"
      asdf install "$lang" "$latest"
      asdf set -u "$lang" "$latest"
    else
      warn "Could not determine latest version for $lang"
    fi
  done

  asdf install lua 5.1.5
  asdf set -u lua 5.1.5

  asdf reshim
else
  warn "asdf not installed; skipping plugin setup"
fi

# ---------- rustup ----------
# if ! command -v rustup >/dev/null 2>&1; then
#   log "Installing Rust toolchain via rustup"
#   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
#   export PATH="$HOME/.cargo/bin:$PATH"
#   rustup toolchain install stable
#   rustup default stable
#   rustup component add rust-analyzer clippy rustfmt
# else
#   log "rustup already present"
# fi

# ---------- neovim (latest stable from GitHub) ----------
log "Checking latest stable Neovim release"

arch="$(uname -m)"
case "$arch" in
x86_64 | amd64) asset="nvim-linux-x86_64.tar.gz" ;;
aarch64 | arm64) asset="nvim-linux-arm64.tar.gz" ;;
*) die "Unsupported arch for Neovim: $arch" ;;
esac

tmp="$(mktemp -d)"
url="https://github.com/neovim/neovim/releases/latest/download/$asset"

log "Downloading $url"
curl -fsSL -o "$tmp/nvim.tar.gz" "$url"

# extract into ~/.local
rm -rf "$HOME/.local/nvim"
tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
extracted_dir="$(tar -tzf "$tmp/nvim.tar.gz" | head -1 | cut -f1 -d"/")"
mv "$tmp/$extracted_dir" "$HOME/.local/nvim"

# symlink into ~/.local/bin
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"

rm -rf "$tmp"

log "Installed Neovim: $($HOME/.local/bin/nvim --version | head -n1)"

# ---------- Neovim config ----------
NVIM_CONFIG="$HOME/.config/nvim"
if [[ -d "$NVIM_CONFIG" ]]; then
  log "Removing existing Neovim config at $NVIM_CONFIG"
  rm -rf "$NVIM_CONFIG"
fi

log "Cloning Neovim config from repo"
git clone git@github.com:jellis206/nvim.git "$NVIM_CONFIG"

# ---------- lazygit ----------
if ! command -v lazygit >/dev/null 2>&1; then
  log "Installing lazygit via Go"
  go install github.com/jesseduffield/lazygit@latest
  # Ensure Go bin is in PATH
  export PATH="$HOME/go/bin:$PATH"
else
  log "lazygit already present: $(lazygit --version 2>/dev/null | head -n1)"
fi

# ---------- tmux & TPM ----------
if ! command -v tmux >/dev/null 2>&1; then
  log "Installing tmux"
  $SUDO apt-get install -y tmux
else
  log "tmux already present: $(tmux -V)"
fi

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
  log "Installing Tmux Plugin Manager (TPM)"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  log "TPM already present at $TPM_DIR"
fi

# ---------- overlay dotfiles ----------
overlay_dotfiles() {
  local subpath="$1"
  local src="$SCRIPT_DIR/$subpath"
  local dest="$HOME/$subpath"

  if [[ -d "$src" ]]; then
    log "Overlaying directory $src → $dest"
    find "$src" -type f | while read -r file; do
      rel="${file#"$src"/}"
      target="$dest/$rel"
      mkdir -p "$(dirname "$target")"
      cp -f "$file" "$target"
      [[ "$subpath" == ".ssh"* ]] && chmod 600 "$target"
      log "Installed $target"
    done
    [[ "$subpath" == ".ssh"* ]] && chmod 700 "$dest"
  elif [[ -f "$src" ]]; then
    log "Overlaying file $src → $dest"
    cp -f "$src" "$dest"
    log "Installed $dest"
  else
    warn "Skipping $subpath (not found)"
  fi
}

# loop over repo contents
for entry in "$SCRIPT_DIR"/.* "$SCRIPT_DIR"/*; do
  name="$(basename "$entry")"
  case "$name" in
  . | .. | .init.sh | .git) continue ;;
  esac
  overlay_dotfiles "$name"
done

log "All set. Open a new terminal or run: exec zsh"
