# 🌌 my-omarchy

Personal customizations, plugins, animations, theme extensions, and system configurations for [Omarchy](https://omarchy.org/) Linux on Arch.

This repository provides a turn-key setup to restore your entire personalized desktop experience, animations, bar plugins, browser theme, and shell environment onto any new Omarchy machine in a single command.

---

## 🌟 Highlights & Customizations

### 1. 🎛️ Adaptive Status Bar (`ludde.bar`)
- **Live Window Color Sampling:** The top bar seamlessly samples the active window's titlebar color using a custom Python sampler script (`sample-window-color.py`), dynamically matching its hue and translucency.
- **Floating Window Intelligence:** Non-fullscreen floating windows (such as `omacalc`) keep the top bar 100% transparent (`alpha = 0.0`) so the underlying wallpaper remains completely unobstructed.
- **Fast Synchronized Transitions:** Color and alpha changes run on an ultra-responsive 180ms cubic ease-out curve, precisely synchronized with Hyprland's workspace slide animation.
- **Dynamic Text Luminance Contrast:** Automatically adjusts text and icon colors between light (`#cdd6f4`) and dark (`#1e1e2e`) depending on the sampled window header luminosity.
- **Frosted Glass Integration:** Integrates 4-pass Gaussian blur with matched 88% opacity on modern glass-styled applications (VS Code, Chromium).
- **Custom Workspaces Widget (`ludde.workspaces`):** Smooth workspace indicator tracking active windows and persistent workspace state.

---

### 2. 🪟 Hyprland Look & Feel & Gestures
- **Custom Deceleration Curves:** Smooth Chromebook-style workspace transitions using custom cubic bezier curves:
  - `fluent_decel`: `{ {0.1, 1}, {1, 1} }` (workspace slide speed = 4)
  - `easeOutExpo`: `{ {0.16, 1}, {0.3, 1} }`
  - `geminiChill`: `{ {0.33, 1}, {0.68, 1} }`
- **Smart Single-Window Gaps & Borders:** Automatically removes window borders and gaps when only a single window occupies a workspace (`w[tv1]s[false]` and `f[1]s[false]`), maximizing screen estate cleanly.
- **oxleovision Popups & Menus:** 23px rounded corners for menus and shell popups, 1px crisp rounding for tiled application windows.
- **Frosted Glass Opacity Rules:**
  - **VS Code:** `0.88` active / `0.82` inactive.
  - **Chromium:** `0.88` active / `0.82` inactive / `1.0` full solid opacity when watching fullscreen media.
- **Blur Layer-Shell Surfaces:** 4-pass Gaussian blur applied across OSD, notifications, bar popups, polkit, and menus.
- **Touchpad Gestures & Dynamic Workspaces (`input.lua`):**
  - 3-finger horizontal touchpad swiping with customized sensitivity (`workspace_swipe_distance = 350`, `cancel_ratio = 0.1`).
  - **Dynamic Persistent Workspaces:** Workspace 1 is permanently pinned; workspaces up to `maxActive + 1` are kept persistent so swipe gestures can navigate continuously to 1 workspace to the right of the highest active window without skipping or unbounded overflow.

---

### 3. 🎨 Chromium Catppuccin Mocha Blue Theme Extension
Located in [`extensions/chromium-theme-catppuccin-mocha/`](extensions/chromium-theme-catppuccin-mocha/) (packaged as [`extensions/catppuccin-mocha-blue.zip`](extensions/catppuccin-mocha-blue.zip)).

Specially tuned to match the browser frame and tab strip seamlessly with the top status bar:
- **Frame & Toolbar Color:** `#1e1e2e` (`rgb(30, 30, 46)`) - Matches Catppuccin Mocha `base` and the Omarchy frosted glass top bar.
- **Active Tab Background:** Seamless with frame `#1e1e2e`.
- **Active Tab Text:** `#ffffff` (`rgb(255, 255, 255)`).
- **Inactive Tab Text:** `#cdd6f4` (`rgb(205, 214, 244)`).
- **Omnibox URL Bar Background:** `#11111b` (`rgb(17, 17, 27)`) - Catppuccin Mocha `crust`.
- **Omnibox Text:** `#ffffff`.
- **New Tab Page (NTP) Background:** `#1e1e2e`.
- **Links:** `#89b4fa` (`rgb(137, 180, 250)`) - Catppuccin Mocha Blue accent.

#### Loading the Theme in Chromium / Chrome / Brave / Edge:
- **Automatic via flags:** Configured in `~/.config/chromium-flags.conf` and `~/.config/brave-flags.conf`:
  ```text
  --load-extension=/home/<username>/.config/chromium/extensions/catppuccin-mocha-blue
  ```
- **Manual via Browser UI:**
  1. Navigate to `chrome://extensions` (or `brave://extensions`).
  2. Toggle **Developer mode** in the top right.
  3. Click **Load unpacked** and select `extensions/chromium-theme-catppuccin-mocha/` (or unpack `extensions/catppuccin-mocha-blue.zip`).

---

### 4. 💻 Terminals & Shell Environment
- **Zsh Profile (`.zshrc`):**
  - **Transient Blue Arrow Prompt:** Previously executed commands collapse cleanly to `%B%F{#89b4fa}❯%f%b ` without multi-line clutter.
  - **Fuzzy Tab Completion:** `fzf-tab` styled with Catppuccin Mocha colors and live `eza` directory previews.
  - Everyday aliases with icons and directory groupings (`eza`, `..`, `...`).
- **Starship Prompt & C Helper:**
  - Fast custom Powerline directory status binary written in C ([`config/starship-powerline-dir.c`](config/starship-powerline-dir.c)) and compiled to `~/.local/bin/starship-powerline-dir`.
  - Continuous gradient connecting headers and git status.
- **Consistent Terminal Profiles:**
  - Configured across **Alacritty** ([`alacritty.toml`](config/alacritty/alacritty.toml)), **Kitty** ([`kitty.conf`](config/kitty/kitty.conf)), and **Ghostty** ([`config`](config/ghostty/config)).
  - Unified font: **Adwaita Mono** (size 8), 14px padding, and Catppuccin theme integration.

---

### 5. 🛠️ Desktop & System Configuration
- **Fontconfig (`fonts.conf`):** Prepend and fallback rules forcing **Noto Color Emoji** across all monospace, sans-serif, and terminal fonts.
- **GTK 4 Glass:** Window styling and transparency via `gtk-4.0/gtk.css`.
- **Fastfetch (`config.jsonc`):** Custom hardware, software, kernel, and Omarchy version layout.
- **Walker Launcher (`config.toml`):** Keyboard-focused launcher with file, symbol, calculator, and clipboard providers.

---

### 6. 🌈 Custom Rainbow Spectrum Backgrounds (`catppuccin/`)
Located in [`config/omarchy/backgrounds/catppuccin/`](config/omarchy/backgrounds/catppuccin/):
A suite of customized 4K wallpapers designed for Catppuccin, retaining the deep navy `#181824` base while introducing vibrant, fluid rainbow spectrum patterns:
- **`rainbow-oil-toned.webp` (Default Active):** 3D liquid-glass / oil swirl adapted from `0xleovision`, tuned with softened highlights (max brightness 170) and rich ruby red/warm amber accents across the main fluid body so blurred frosted glass does not overpower white UI text.
- **`rainbow-oil-velvet.webp`:** Deep, ultra-soft highlight ceiling (max brightness 122) with subtle crimson and iridescent shimmer for maximum text legibility under translucent panels.
- **`rainbow-oil-slick.webp`:** High-contrast vibrant 3D liquid-glass swirl with intense specular reflections.
- **`rainbow-oil-wave.webp`:** Broad 3D metallic/fluid wave filling the upper display with iridescent rainbow sheen.
- **`rainbow-waves-ribbon.webp`:** Multi-strand stacked spectrum bands in classic ColecoVision / Activision ribbon style.
- **`rainbow-waves-horizontal.webp`:** Smooth horizontal rainbow transition sweeping across thin wave lines.
- **`rainbow-waves-prism.webp`:** Diagonal prism sweep across the wave bundle.

---

## 📂 Repository Structure

```text
my-omarchy/
├── install.sh                                  # Automated one-step restoration script
├── README.md                                   # Comprehensive documentation
├── extensions/
│   ├── catppuccin-mocha-blue.zip               # Pre-packaged ready-to-load extension zip
│   └── chromium-theme-catppuccin-mocha/        # Unpacked Chromium theme extension
│       ├── manifest.json                       # Frame #1e1e2e theme colors & styling
│       ├── images/                             # Extension icons
│       └── README.md                           # Extension loading guide
├── config/
│   ├── hypr/                                   # Hyprland lua configuration & rules
│   │   ├── hyprland.lua                        # Hyprland root bootstrap & loader
│   │   ├── looknfeel.lua                       # Curves, opacity, smart gaps, blur
│   │   ├── input.lua                           # Gestures & dynamic persistent workspaces
│   │   ├── bindings.lua                        # Keybinding overrides
│   │   ├── monitors.lua                        # Display resolutions & GDK scale
│   │   └── autostart.lua                       # Startup services
│   ├── omarchy/                                # Omarchy shell & custom QML plugins
│   │   ├── backgrounds/catppuccin/             # Custom 4K rainbow spectrum & oil-slick wallpapers
│   │   ├── shell.json                          # Bar layout & active plugins
│   │   ├── shell.toml                          # Alpha, border widths, corner roundings
│   │   ├── hooks/                              # Post-update and theme hooks
│   │   └── plugins/
│   │       ├── ludde.bar/                      # Adaptive top bar & color sampler
│   │       │   ├── Bar.qml
│   │       │   ├── BarModel.js
│   │       │   ├── sample-window-color.py
│   │       │   ├── indicators/
│   │       │   └── widgets/
│   │       └── ludde.workspaces/               # Workspace switcher plugin
│   ├── alacritty/alacritty.toml                # Alacritty configuration
│   ├── kitty/kitty.conf                        # Kitty configuration
│   ├── ghostty/config                          # Ghostty configuration
│   ├── fontconfig/fonts.conf                   # Font and emoji preferences
│   ├── gtk-4.0/gtk.css                         # GTK 4 glass theme
│   ├── walker/config.toml                      # Walker launcher settings
│   ├── fastfetch/config.jsonc                  # System info display
│   ├── waybar/                                 # Waybar backup layout & style
│   ├── chromium-flags.conf                     # Wayland flags & auto-load extension
│   ├── brave-flags.conf                        # Brave browser flags
│   ├── starship.toml                           # Starship prompt configuration
│   ├── starship-powerline-dir.c                # C prompt helper source code
│   └── chromium/extensions/
│       └── catppuccin-mocha-blue/              # Installed extension location
└── shell/
    ├── .zshrc                                  # Zsh profile, transient prompt, fzf-tab
    └── .bashrc                                 # Bash profile
```

---

## 🚀 Restoration on a New Computer

On a fresh Omarchy Linux installation:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/LuddePro05/my-omarchy.git ~/Work/my-omarchy
   cd ~/Work/my-omarchy
   ```

2. **Run the restoration script:**
   ```bash
   ./install.sh
   ```

### What `install.sh` Does Automatically:
1. **Backs up** existing configs to `~/.config/omarchy-backup-<timestamp>`.
2. **Deploys** all configurations into `~/.config/` and installs the Chromium theme extension to `~/.config/chromium/extensions/catppuccin-mocha-blue`.
3. **Adapts paths** in `chromium-flags.conf` and `brave-flags.conf` to match the target machine's `$HOME`.
4. **Sets executable permissions** on `sample-window-color.py` and hook scripts.
5. **Clones missing shell plugins:** `omaplug`, `omapods`, `omasend`, and `fzf-tab`.
6. **Compiles** `starship-powerline-dir.c` into `~/.local/bin/starship-powerline-dir` using `gcc`.
7. **Installs shell profiles** (`~/.zshrc` and `~/.bashrc`).
8. **Applies the Catppuccin theme** and activates the custom frosted-glass-optimized rainbow background (`rainbow-oil-toned.webp`).
9. **Reloads** Hyprland and restarts the Omarchy shell to activate all changes instantly.
