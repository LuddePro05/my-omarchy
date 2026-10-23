#!/usr/bin/env bash
# ==============================================================================
#  my-omarchy : One-step restoration and setup script
#  Restores all custom Hyprland, Omarchy shell, bar plugins, animations,
#  terminals, prompt, and Catppuccin theme customizations on a new machine.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/omarchy-backup-$(date +%Y%m%d_%H%M%S)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Restoring my-omarchy Customizations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Backup existing configs if they exist
echo "📦 Backing up existing configs to: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Ensure Kitty terminal is installed
if command -v omarchy-pkg-add &>/dev/null; then
  echo "🐱 Ensuring Kitty is installed..."
  omarchy-pkg-add kitty 2>/dev/null || sudo pacman -S --noconfirm --needed kitty 2>/dev/null || true
fi

for item in hypr omarchy alacritty kitty ghostty fontconfig gtk-4.0 fastfetch walker waybar chromium-flags.conf brave-flags.conf starship.toml Code Typora nvim; do
  if [ -e "$HOME/.config/$item" ]; then
    cp -a "$HOME/.config/$item" "$BACKUP_DIR/"
  fi
done

[ -f "$HOME/.zshrc" ] && cp -a "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"
[ -f "$HOME/.bashrc" ] && cp -a "$HOME/.bashrc" "$BACKUP_DIR/.bashrc"

# 2. Deploy ~/.config items
echo "📁 Deploying configurations into ~/.config..."
mkdir -p "$HOME/.config"
cp -a "$SCRIPT_DIR/config/"* "$HOME/.config/"

# Ensure Chromium custom Catppuccin theme extension is installed
mkdir -p "$HOME/.config/chromium/extensions"
cp -a "$SCRIPT_DIR/extensions/chromium-theme-catppuccin-mocha" "$HOME/.config/chromium/extensions/catppuccin-mocha-blue"

# Fix any hardcoded home paths in flag files for the new user's username
if [ -f "$HOME/.config/chromium-flags.conf" ]; then
  sed -i "s|/home/[^/]*|$HOME|g" "$HOME/.config/chromium-flags.conf"
fi
if [ -f "$HOME/.config/brave-flags.conf" ]; then
  sed -i "s|/home/[^/]*|$HOME|g" "$HOME/.config/brave-flags.conf"
fi

# 3. Ensure executable permissions on scripts & hooks
echo "🔧 Setting executable permissions on scripts and hooks..."
chmod +x "$HOME/.config/omarchy/plugins/ludde.bar/sample-window-color.py" 2>/dev/null || true
if [ -d "$HOME/.config/omarchy/hooks" ]; then
  find "$HOME/.config/omarchy/hooks" -type f -name "*.hook" -exec chmod +x {} + 2>/dev/null || true
  find "$HOME/.config/omarchy/hooks" -type f -name "*-sync" -exec chmod +x {} + 2>/dev/null || true
fi

# 4. Clone third-party Omarchy shell plugins if missing
echo "🔌 Ensuring shell plugins are present..."
mkdir -p "$HOME/.config/omarchy/plugins"

if [ ! -d "$HOME/.config/omarchy/plugins/omaplug" ]; then
  echo "  - Cloning omaplug..."
  git clone https://github.com/fross100/omaplug.git "$HOME/.config/omarchy/plugins/omaplug"
fi

if [ ! -d "$HOME/.config/omarchy/plugins/io.github.thisisgm.omapods" ]; then
  echo "  - Cloning omapods..."
  git clone https://github.com/thisisgm/omarchy-pods "$HOME/.config/omarchy/plugins/io.github.thisisgm.omapods"
fi

if [ ! -d "$HOME/.config/omarchy/plugins/nosignal.omasend" ]; then
  echo "  - Cloning omasend..."
  git clone https://github.com/28allday/omasend-quattro.git "$HOME/.config/omarchy/plugins/nosignal.omasend"
fi

# 5. Clone zsh fzf-tab plugin if missing
if [ ! -d "$HOME/.zsh/fzf-tab" ]; then
  echo "  - Cloning zsh fzf-tab plugin..."
  mkdir -p "$HOME/.zsh"
  git clone https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/fzf-tab"
fi

# 6. Build starship-powerline-dir helper if gcc is available
if [ -f "$HOME/.config/starship-powerline-dir.c" ]; then
  if command -v gcc &>/dev/null; then
    echo "⚙️  Compiling starship-powerline-dir binary..."
    mkdir -p "$HOME/.local/bin"
    gcc -O3 -o "$HOME/.local/bin/starship-powerline-dir" "$HOME/.config/starship-powerline-dir.c"
    chmod +x "$HOME/.local/bin/starship-powerline-dir"
  else
    echo "⚠️  gcc not found; install gcc to compile the powerline directory helper."
  fi
fi

# 7. Shell rc files
echo "🐚 Deploying shell profiles (.zshrc, .bashrc)..."
cp -a "$SCRIPT_DIR/shell/.zshrc" "$HOME/.zshrc"
cp -a "$SCRIPT_DIR/shell/.bashrc" "$HOME/.bashrc"

# 8. Set Catppuccin theme and custom background
echo "🎨 Applying Catppuccin theme and custom rainbow background..."
if command -v omarchy &>/dev/null; then
  omarchy theme set catppuccin || true
  if [ -f "$HOME/.config/omarchy/backgrounds/catppuccin/rainbow-oil-toned.webp" ]; then
    echo "🖼️  Setting custom rainbow oil slick background..."
    omarchy theme bg set "$HOME/.config/omarchy/backgrounds/catppuccin/rainbow-oil-toned.webp" || true
  fi
  if command -v omarchy-theme-bg-cache &>/dev/null; then
    omarchy theme bg cache 2>/dev/null || true
  fi
fi

# 9. Reload Hyprland and Omarchy Shell
echo "🔄 Reloading Hyprland and restarting Omarchy Shell..."
if command -v hyprctl &>/dev/null; then
  hyprctl reload || true
fi

if command -v omarchy-restart-shell &>/dev/null; then
  omarchy-restart-shell || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Restoration complete!"
echo "  All your custom settings, adaptive bar, animations,"
echo "  and glass opacities are now active."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
