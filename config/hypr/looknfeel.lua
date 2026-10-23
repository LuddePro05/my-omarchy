-- Change the default Omarchy look'n'feel.

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.
o.transparent_window("(com\\.microsoft\\.VSCode|code-url-handler|code)", "0.90 0.85")


-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
--
-- Change the default Omarchy look'n'feel.

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 2,
    border_size = 0,
  },
  decoration = {
    -- Setting global rounding to 23 aligns Omarchy shell popups and menus with oxleovision.
    -- Workspace windows are pinned to rounding = 3 via window rules below.
    rounding = 23,

    blur = {
      enabled = true,
      size = 10,
      passes = 4,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
      noise = 0.0,
      contrast = 1.05,
      brightness = 0.85,
      vibrancy = 0.2,
      vibrancy_darkness = 0.0,
      popups = true,
      special = true,
    },
  },
})

-- Keep workspace windows at corner rounding = 3, no outline/border
hl.window_rule({ match = { class = ".*" }, rounding = 3, border_size = 0 })
hl.window_rule({ match = { title = ".*" }, rounding = 3, border_size = 0 })

-- Define your custom Chromebook-style curves
hl.curve("fluent_decel", { type = "bezier", points = { {0.1, 1}, {1, 1} } })
hl.curve("easeOutExpo", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
hl.curve("geminiChill", { type = "bezier", points = { {0.33, 1}, {0.68, 1} } })

-- Apply the curve to workspace transitions
hl.animation({ 
  leaf = "workspaces", 
  enabled = true, 
  speed = 4, 
  bezier = "fluent_decel", 
  style = "slide" 
})

-- Smart borders & gaps: remove outline and gaps when only one window is on the workspace
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, border_size = 0, rounding = 0 })

-- --- oxleovision Transparency Effects ---------------------------------------
o.window({ tag = "default-opacity" }, { opacity = "1 0.84" })
o.window({ tag = "transparent-window" }, { opacity = "1 0.84" })

-- VS Code frosted glass transparency (evaluated after transparent-window so active state stays glassy)
hl.window_rule({
  match = { class = "(com\\.microsoft\\.VSCode|code-url-handler|[cC]ode)" },
  opacity = "0.88 0.82",
})
hl.window_rule({
  match = { initial_class = "(com\\.microsoft\\.VSCode|code-url-handler|[cC]ode)" },
  opacity = "0.88 0.82",
})

-- Chrome / Chromium frosted glass transparency (subtle when active, glassier when inactive, fully solid in fullscreen)
hl.window_rule({
  match = { class = "((google-)?[cC]hrom(e|ium)|chromium-browser)" },
  opacity = "0.88 0.82 1.0",
})
hl.window_rule({
  match = { initial_class = "((google-)?[cC]hrom(e|ium)|chromium-browser)" },
  opacity = "0.88 0.82 1.0",
})

-- Obsidian frosted glass transparency (pronounced frosted glass effect, solid in fullscreen)
hl.window_rule({
  match = { class = "([oO]bsidian|md\\.obsidian\\.Obsidian)" },
  opacity = "0.78 0.72 1.0",
})
hl.window_rule({
  match = { initial_class = "([oO]bsidian|md\\.obsidian\\.Obsidian)" },
  opacity = "0.78 0.72 1.0",
})

-- Blur layer-shell surfaces
hl.layer_rule({ match = { namespace = "omarchy-osd" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "omarchy-notifications" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true, blur_popups = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "omarchy-menu" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "omarchy-polkit" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "^(omarchy-emojis|omarchy-clipboard|omarchy-image-selector|omarchy-keyboard-panel|omarchy-polkit|omarchy-reminders|omarchy-network-qr)$" }, blur = true, ignore_alpha = 0.3 })


