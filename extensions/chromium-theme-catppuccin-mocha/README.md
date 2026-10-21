# 🎨 Catppuccin Mocha Blue - Chromium Theme Extension

Custom Catppuccin Mocha Blue theme extension for Chromium, Google Chrome, Brave, and Microsoft Edge on Linux.

Specially tuned to provide a seamless, bezel-less visual transition between the browser frame/tab strip and Omarchy's adaptive status bar (`ludde.bar`).

---

## 🌟 Visual Specifications

- **Frame & Toolbar Color:** `#1e1e2e` (`rgb(30, 30, 46)`) - Matches Catppuccin Mocha `base` and the Omarchy frosted glass top bar.
- **Active Tab Background:** Seamless with frame `#1e1e2e`.
- **Active Tab Text:** `#ffffff` (`rgb(255, 255, 255)`).
- **Inactive Tab Text:** `#cdd6f4` (`rgb(205, 214, 244)`).
- **Omnibox URL Bar Background:** `#11111b` (`rgb(17, 17, 27)`) - Catppuccin Mocha `crust`.
- **Omnibox Text:** `#ffffff`.
- **New Tab Page (NTP) Background:** `#1e1e2e`.
- **Links:** `#89b4fa` (`rgb(137, 180, 250)`) - Catppuccin Mocha Blue accent.

---

## 🚀 Installation & Loading

### Method 1: Automatic via flags (Omarchy Default)
In `~/.config/chromium-flags.conf` (or `~/.config/brave-flags.conf`), add:
```text
--load-extension=/home/<username>/.config/chromium/extensions/catppuccin-mocha-blue
```
This automatically loads the theme every time the browser launches.

### Method 2: Manual Installation via Browser UI
1. Open your browser and navigate to `chrome://extensions` (or `brave://extensions` / `edge://extensions`).
2. Enable **Developer mode** using the toggle switch in the top right.
3. Click **Load unpacked**.
4. Select this directory (`extensions/chromium-theme-catppuccin-mocha` or `~/.config/chromium/extensions/catppuccin-mocha-blue`).
5. The Catppuccin Mocha Blue theme applies immediately!

Alternatively, you can unpack `catppuccin-mocha-blue.zip` and load that directory.
