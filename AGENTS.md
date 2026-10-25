# Antigravity User Preferences & Omarchy Configuration Memory

## Omarchy Customization & GitHub Synchronization
- **Personal Repository**: All personal Omarchy and desktop configurations are version-controlled in this repository (`git@github.com:LuddePro05/my-omarchy.git`, branch `main`).
- **Automatic GitHub Sync**:
  - Before modifying desktop, Hyprland, Quickshell, or Omarchy configurations, review this repository for user preferences and commit history.
  - Whenever files in `~/.config/` (such as `~/.config/omarchy/`, `~/.config/hypr/`, etc.) are modified, always mirror those changes here and commit/push to GitHub `main`.

## Current Desktop & Shell Preferences
- **Screensaver Branding**:
  - Text is `"LUDWIG EMSJO"` in `~/.config/omarchy/branding/screensaver.txt`.
  - The topbar unmaps and hides automatically whenever the screensaver window activates.
- **Topbar (`ludde.bar`)**:
  - **Layout**: 3-island floating pill design:
    - Left pill: Workspaces (`ludde.workspaces`).
    - Center pill: Clock (`ludde.clock`), weather, updates, herdr, and system indicators.
    - Right pill: System tray, volume, battery, network, bluetooth, power.
  - **Pill Styling**:
    - Borderless: `border.width: 0` and `border.color: "transparent"`.
    - Pill background: dynamically matches the bar's adaptive background, tuned ~20% brighter via `pillBackground` (`Qt.lighter(background, 1.20)` / `Qt.darker(background, 1.10)`).
    - Drop shadow: rendered with `MultiEffect` (`shadowColor: Qt.rgba(0, 0, 0, 0.65)`, `shadowBlur: 0.7`, `shadowVerticalOffset: 2`).
    - Bar surface geometry: 32px height to provide 4px margin top and bottom so pills float with no bezel clipping and shadows render cleanly.
- **Safety Guidelines**:
  - NEVER edit anything under `/usr/share/omarchy/` (read-only system defaults).
  - Always back up user configs before editing (`*.bak.<timestamp>`).
