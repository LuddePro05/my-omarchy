-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty)", { scroll_touchpad = 1.5 })
-- o.window("foot", { scroll_touchpad = 2.0 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
--
hl.config({
  input = {
    kb_variant = "nodeadkeys",
  },
  gestures = {
    workspace_swipe_invert = false,
    workspace_swipe_distance = 350,
    workspace_swipe_forever = true,
    workspace_swipe_min_speed_to_force = 5,
    workspace_swipe_cancel_ratio = 0.1
  }
})

-- Navigate focus between windows on the active workspace with seamless edge wrapping
local function navigate_focus(dir)
  local cur = hl.get_active_window()
  if not cur then return end

  hl.dispatch(hl.dsp.focus({ direction = dir }))
  local nxt = hl.get_active_window()

  -- If focus didn't change, we reached the end of the window columns: wrap around (only if 3+ windows)
  if nxt and nxt.address == cur.address then
    local windows = hl.get_windows() or {}
    local ws_windows = {}
    local cur_ws_id = cur.workspace and cur.workspace.id
    for _, w in ipairs(windows) do
      if w and w.workspace and w.workspace.id == cur_ws_id and not w.floating then
        table.insert(ws_windows, w)
      end
    end

    table.sort(ws_windows, function(a, b)
      local ax = (a.at and a.at.x) or 0
      local bx = (b.at and b.at.x) or 0
      return ax < bx
    end)

    -- Skip wrapping if there are only 2 (or fewer) windows to prevent overshooting
    if #ws_windows > 2 then
      if dir == "r" then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. ws_windows[1].address }))
      else
        hl.dispatch(hl.dsp.focus({ window = "address:" .. ws_windows[#ws_windows].address }))
      end
    end
  end
end

_G.navigate_focus = navigate_focus

-- Three-finger vertical swipe switches workspaces up and down
hl.gesture({ fingers = 3, direction = "vertical", scale = 1.1, action = "workspace" })

-- Three-finger horizontal swipe moves focus between windows (latched to trigger exactly once per stroke)
local swipe_accum_x = 0
local swipe_triggered = false

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = {
    start = function()
      swipe_accum_x = 0
      swipe_triggered = false
    end,
    update = function(e)
      if not swipe_triggered and e and e.delta and e.delta.x then
        swipe_accum_x = swipe_accum_x + e.delta.x
        if swipe_accum_x > 40 then
          swipe_triggered = true
          navigate_focus("r")
        elseif swipe_accum_x < -40 then
          swipe_triggered = true
          navigate_focus("l")
        end
      end
    end,
    finish = function()
      swipe_accum_x = 0
      swipe_triggered = false
    end,
    ["end"] = function()
      swipe_accum_x = 0
      swipe_triggered = false
    end,
  },
})

-- Dynamically manage persistent workspaces and auto-collapse empty middle workspaces:
-- Workspace 1 can never disappear.
-- Workspaces up to (maxActive + 1) are kept persistent so trackpad swipe gestures
-- can navigate continuously to 1 workspace to the right of the highest active window,
-- without skipping empty workspaces or allowing navigation beyond that.
--
-- If an intermediate workspace is emptied (e.g. windows on 1, 2, 3, 4 and all windows
-- on 2 are closed/moved), subsequent workspaces collapse left (3->2, 4->3), keeping
-- active workspaces contiguous and leaving only the one right after them empty.
local timer_pending = false
local is_collapsing = false

local function collapse_workspaces()
  if is_collapsing then return end
  is_collapsing = true

  local ok, err = pcall(function()
    local all_windows = hl.get_windows() or {}

    -- Identify workspace blocks (base 0 for 1..10, base 10 for 11..20, etc.)
    local bases = {}
    bases[0] = true
    for _, w in ipairs(all_windows) do
      if w and w.workspace and type(w.workspace.id) == "number" and not w.pinned and w.workspace.id > 0 then
        local b = math.floor((w.workspace.id - 1) / 10) * 10
        bases[b] = true
      end
    end

    local active_ws = hl.get_active_workspace()
    local active_ws_id = active_ws and active_ws.id
    local active_win = hl.get_active_window()
    local active_win_addr = active_win and active_win.address
    local active_win_ws = active_win and active_win.workspace and active_win.workspace.id

    for base in pairs(bases) do
      local windows_by_ws = {}
      for id = base + 1, base + 10 do
        windows_by_ws[id] = {}
      end

      for _, w in ipairs(all_windows) do
        if w and w.workspace and type(w.workspace.id) == "number" and not w.pinned then
          local wid = w.workspace.id
          if wid >= base + 1 and wid <= base + 10 then
            table.insert(windows_by_ws[wid], w)
          end
        end
      end

      local occupied = {}
      for id = base + 1, base + 10 do
        if #windows_by_ws[id] > 0 then
          table.insert(occupied, id)
        end
      end

      -- Check if any workspace needs shifting
      local needs_shift = false
      for i, src_ws in ipairs(occupied) do
        local target_ws = base + i
        if src_ws ~= target_ws then
          needs_shift = true
          break
        end
      end

      if needs_shift then
        local ws_map = {}
        for i, src_ws in ipairs(occupied) do
          local target_ws = base + i
          ws_map[src_ws] = target_ws

          if src_ws ~= target_ws then
            -- Sort windows left-to-right to preserve column order
            table.sort(windows_by_ws[src_ws], function(a, b)
              local ax = (a.at and a.at.x) or 0
              local bx = (b.at and b.at.x) or 0
              return ax < bx
            end)

            for _, w in ipairs(windows_by_ws[src_ws]) do
              hl.dispatch(hl.dsp.window.move({
                workspace = tostring(target_ws),
                follow = false,
                window = "address:" .. w.address
              }))
            end
          end
        end

        -- Update focus so user stays with their active window or workspace
        if active_win and active_win_ws and ws_map[active_win_ws] then
          local new_ws = ws_map[active_win_ws]
          if new_ws ~= active_win_ws then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(new_ws) }))
            hl.dispatch(hl.dsp.focus({ window = "address:" .. active_win_addr }))
          end
        elseif active_ws_id and active_ws_id >= base + 1 and active_ws_id <= base + 10 then
          if ws_map[active_ws_id] then
            local new_ws = ws_map[active_ws_id]
            if new_ws ~= active_ws_id then
              hl.dispatch(hl.dsp.focus({ workspace = tostring(new_ws) }))
            end
          else
            local target_focus = math.min(active_ws_id, base + math.max(1, #occupied + 1))
            if target_focus ~= active_ws_id then
              hl.dispatch(hl.dsp.focus({ workspace = tostring(target_focus) }))
            end
          end
        end
      end
    end
  end)

  if not ok then
    print("collapse_workspaces error: " .. tostring(err))
  end

  is_collapsing = false
end

local function update_persistent_workspaces()
  local ok, err = pcall(function()
    local windows = hl.get_windows() or {}
    local bases = {}
    bases[0] = true
    for _, w in ipairs(windows) do
      if w and w.workspace and type(w.workspace.id) == "number" and not w.pinned and w.workspace.id > 0 then
        local b = math.floor((w.workspace.id - 1) / 10) * 10
        bases[b] = true
      end
    end

    for base in pairs(bases) do
      local maxActive = base + 1
      for _, w in ipairs(windows) do
        if w and w.workspace and type(w.workspace.id) == "number" and not w.pinned then
          local wid = w.workspace.id
          if wid >= base + 1 and wid <= base + 10 and wid > maxActive then
            maxActive = wid
          end
        end
      end

      local limit = math.min(base + 10, maxActive + 1)
      for id = base + 1, limit do
        hl.workspace_rule({ workspace = tostring(id), persistent = true, layout = "scrolling" })
      end
      for id = limit + 1, base + 10 do
        hl.workspace_rule({ workspace = tostring(id), persistent = false, layout = "scrolling" })
      end
    end
  end)
  if not ok then
    print("update_persistent_workspaces error: " .. tostring(err))
  end
end

local function schedule_workspace_update()
  if not timer_pending then
    timer_pending = true
    hl.timer(function()
      timer_pending = false
      if not is_collapsing then
        collapse_workspaces()
      end
      update_persistent_workspaces()
    end, { timeout = 50, type = "oneshot" })
  end
end

local function on_workspace_state_change()
  if is_collapsing then return end
  schedule_workspace_update()
end

update_persistent_workspaces()

hl.on("window.open", function()
  if is_collapsing then return end
  update_persistent_workspaces()
  schedule_workspace_update()
end)
hl.on("window.close", on_workspace_state_change)
hl.on("window.destroy", on_workspace_state_change)
hl.on("window.move_to_workspace", on_workspace_state_change)
hl.on("workspace.active", schedule_workspace_update)
hl.on("config.reloaded", function()
  collapse_workspaces()
  update_persistent_workspaces()
end)

