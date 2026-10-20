# 🌌 my-omarchy

Personal customizations, plugins, animations, and configurations for [Omarchy](https://omarchy.org/) Linux on Arch.

This repository allows full restoration of your personalized desktop experience, animations, bar plugins, and shell environment onto a fresh Omarchy machine in a single command.

---

## 🌟 Highlights & Customizations

### 1. Adaptive Status Bar (`ludde.bar`)
- **Real-Time Window Adaptation:** The top bar seamlessly samples the active window's titlebar color using a custom Python sampler (`sample-window-color.py`) and dynamically matches its hue and opacity.
- **Floating Window Intelligence:** Non-fullscreen floating windows (such as `omacalc`) keep the top bar 100% transparent so the background wallpaper remains visible.
- **Fast Synchronized Transitions:** Color and alpha changes run on an ultra-smooth 180ms cubic ease-out curve, timed with Hyprland's workspace slide.
- **Dynamic Text Luminance Contrast:** Automatically adjusts text and icon colors between light (`#cdd6f4`) and dark (`#1e1e2e`) depending on the sampled window header luminosity.
- **Frosted Glass Integration:** Integrates 4-pass Gaussian blur with matched 88% opacity on modern glass-styled applications (VS Code, Chromium).

### 2. Hyprland Look & Feel & Gestures
- **Custom Deceleration Curves:** Smooth Chromebook-style workspace transitions using custom cubic bezier curves (`fluent_decel`, `easeOutExpo`, `geminiChill`).
- **Smart Single-Window Gaps & Borders:** Automatically removes window borders and gaps when only a single window occupies a workspace, maximizing screen real estate cleanly.
- **oxleovision Popups & Menus:** 23px rounded corners for menus and shell popups, 1px crisp rounding for tiled application windows.
- **Frosted Glass Opacity Rules:**
  - **VS Code:** `0.88` active / `0.82` inactive.
  - **Chromium:** `0.88` active / `0.82` inactive / `1.0` full opacity when watching fullscreen media.
- **Dynamic Persistent Workspaces & Touchpad Gestures:** 3-finger horizontal touchpad swiping with dynamic workspace persistence (workspace 1 is always pinned; swiping allows navigation to the next available workspace without overflow).

### 3. Terminals & Prompt
- **Zsh & Starship Prompt:**
  - High-performance custom Powerline directory status binary written in C (`starship-powerline-dir.c`).
  - Transient prompt: collapses previously executed commands cleanly to a blue arrow (`❯`).
  - `fzf-tab` fuzzy completion styled with Catppuccin Mocha colors and live `eza` directory previews.
- **Terminal Configurations:** Consistent Adwaita Mono font (size 8), 14px padding, and Catppuccin Mocha theme integration across **Alacritty**, **Kitty**, and **Ghostty**.

### 4. Chromium Integration
- Custom Catppuccin Mocha Blue theme extension (`catppuccin-mocha-blue`) matching the top bar and system color scheme.
- Configured in `chromium-flags.conf` with 0.90 scaling factor, touch gestures, and Wayland flags.

---

## 📂 Repository Structure

```text
my-omarchy/
├── install.sh                  # Complete automated restore script
├── README.md                   # Documentation
├── config/
│   ├── hypr/                   # Hyprland lua configs & window rules
│   │   ├── hyprland.lua
│   │   ├── looknfeel.lua
│   │   ├── input.lua
│   │   ├── bindings.lua
│   │   ├── monitors.lua
│   │   └── autostart.lua
│   ├── omarchy/                # Shell config & custom QML plugins
│   │   ├── shell.json
│   │   ├── shell.toml
│   │   ├── hooks/
│   │   └── plugins/
│   │       ├── ludde.bar/      # Adaptive status bar & color sampler
│   │       └── ludde.workspaces/
│   ├── alacritty/              # Alacritty terminal config
│   ├── kitty/                  # Kitty terminal config
│   ├── ghostty/                # Ghostty terminal config
│   ├── fontconfig/             # Emoji fallback & font aliases
│   ├── gtk-4.0/                # GTK glass styles
│   ├── walker/                 # Walker application launcher
│   ├── fastfetch/              # Custom fastfetch specs
│   ├── waybar/                 # Waybar backup config
│   ├── chromium-flags.conf     # Wayland & extension flags for Chromium
│   ├── brave-flags.conf        # Browser flags for Brave
│   ├── starship.toml           # Starship prompt configuration
│   ├── starship-powerline-dir.c# Source code for fast prompt helper
│   └── chromium/extensions/
│       └── catppuccin-mocha-blue/
└── shell/
    ├── .zshrc                  # Zsh profile & transient prompt
    └── .bashrc                 # Bash profile
```

---

## 🚀 Restoration on a New Computer

On a fresh Omarchy Linux installation:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/LuddePro05/my-omarchy.git ~/Work/my-omarchy
   cd ~/Work/my-omarchy
   ```

2. **Run the installer:**
   ```bash
   ./install.sh
   ```

The script will:
1. Automatically back up existing configurations to `~/.config/omarchy-backup-<timestamp>`.
2. Copy all desktop and application configs into `~/.config/`.
3. Set executable permissions on hooks and Python sampling scripts.
4. Clone required Omarchy shell plugins (`omaplug`, `omapods`, `omasend`) and `fzf-tab`.
5. Compile the C helper `starship-powerline-dir` to `~/.local/bin/`.
6. Deploy `.zshrc` and `.bashrc`.
7. Activate the Catppuccin theme and reload Hyprland and the Omarchy Shell.
