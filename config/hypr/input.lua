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

-- Navigate focus between windows on the active workspace without wrap-around
local function navigate_focus(dir)
  hl.dispatch(hl.dsp.focus({ direction = dir }))
end

_G.navigate_focus = navigate_focus

-- Toggle window between normal column width and fullscreen width (1.0),
-- inflating to push adjacent windows aside in scrolling layout instead of hiding them.
local previous_column_widths = {}

local function toggle_fullscreen_inflate()
  local win = hl.get_active_window()
  if not win then return end

  -- If floating or in native fullscreen, use normal fullscreen toggle
  if win.floating or (win.fullscreen and win.fullscreen ~= 0) then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))
    return
  end

  local mon = hl.get_active_monitor()
  local mon_width = (mon and mon.width) or 1920

  -- If already taking up roughly the full screen width (>= 85%)
  if win.size and win.size.x and win.size.x >= mon_width * 0.85 then
    local target_width = previous_column_widths[win.address] or 0.49
    previous_column_widths[win.address] = nil
    hl.dispatch(hl.dsp.layout("colresize " .. string.format("%.2f", target_width)))
    hl.dispatch(hl.dsp.layout("fit visible"))
  else
    if win.size and win.size.x and mon_width > 0 then
      previous_column_widths[win.address] = win.size.x / mon_width
    end
    hl.dispatch(hl.dsp.layout("colresize 1.0"))
    hl.dispatch(hl.dsp.layout("fit active"))
  end
end

_G.toggle_fullscreen_inflate = toggle_fullscreen_inflate

-- Three-finger vertical swipe switches workspaces up and down
hl.gesture({ fingers = 3, direction = "vertical", scale = 1.1, action = "workspace" })

-- Three-finger horizontal swipe moves focus between windows with Chromebook-like physics:
-- sensitivity dynamically scales with the number of workspaces/windows so that a full
-- edge-to-edge swipe spans across the entire strip to the far right/left, with swipe
-- length and drag speed naturally increasing travel distance without overshooting.
local stroke_dist_x = 0
local stroke_steps_taken = 0
local stroke_peak_speed = 0
local stroke_direction = 0 -- 1 for right, -1 for left
local last_step_time = 0

local TRACKPAD_SPAN = 380
local MIN_STEP_INTERVAL_MS = 140

local function get_layout_info()
  local cur = hl.get_active_window()
  local cur_ws_id = cur and cur.workspace and cur.workspace.id
  if not cur_ws_id then
    local ws = hl.get_active_workspace()
    cur_ws_id = ws and ws.id
  end

  local all_windows = hl.get_windows() or {}
  local ws_windows = {}
  for _, w in ipairs(all_windows) do
    if w and w.workspace and w.workspace.id == cur_ws_id and not w.floating and not w.pinned then
      table.insert(ws_windows, w)
    end
  end

  table.sort(ws_windows, function(a, b)
    local ax = (a.at and a.at.x) or 0
    local bx = (b.at and b.at.x) or 0
    return ax < bx
  end)

  local cur_idx = 1
  if cur then
    for i, w in ipairs(ws_windows) do
      if w.address == cur.address then
        cur_idx = i
        break
      end
    end
  end

  -- Count active workspaces in current monitor block
  local base = 0
  if cur_ws_id and cur_ws_id > 0 then
    base = math.floor((cur_ws_id - 1) / 10) * 10
  end

  local max_active_ws = base + 1
  for _, w in ipairs(all_windows) do
    if w and w.workspace and type(w.workspace.id) == "number" and not w.pinned then
      local wid = w.workspace.id
      if wid >= base + 1 and wid <= base + 10 and wid > max_active_ws then
        max_active_ws = wid
      end
    end
  end
  local ws_count = max_active_ws - base
  local total_items = math.max(#ws_windows, ws_count, 2)

  return {
    cur_idx = cur_idx,
    total_windows = #ws_windows,
    total_items = total_items,
    steps_left = cur_idx - 1,
    steps_right = math.max(0, #ws_windows - cur_idx),
  }
end

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = {
    start = function()
      stroke_dist_x = 0
      stroke_steps_taken = 0
      stroke_peak_speed = 0
      stroke_direction = 0
      last_step_time = 0
    end,
    update = function(e)
      if not (e and e.delta and e.delta.x) then return end
      local dx = e.delta.x
      local now = (e and e.time_ms) or (os.clock() * 1000)

      -- Track peak velocity during this stroke
      local speed = math.abs(dx)
      if speed > stroke_peak_speed then
        stroke_peak_speed = speed
      end

      -- Turnaround detection: if user reverses direction, reset stroke accumulation
      if (stroke_direction > 0 and dx < -2) or (stroke_direction < 0 and dx > 2) then
        stroke_dist_x = 0
        stroke_steps_taken = 0
        stroke_peak_speed = speed
        stroke_direction = dx > 0 and 1 or -1
      elseif stroke_direction == 0 and math.abs(dx) > 1 then
        stroke_direction = dx > 0 and 1 or -1
      end

      stroke_dist_x = stroke_dist_x + dx

      local info = get_layout_info()
      local total_steps = math.max(1, info.total_items - 1)
      local step_dist = TRACKPAD_SPAN / total_steps

      -- Velocity gain: slow drag = 1.0x (1-to-1 distance); fast flick boosts up to 2.4x
      local velocity_gain = 1.0
      if stroke_peak_speed > 6 then
        velocity_gain = 1.0 + math.min(1.4, ((stroke_peak_speed - 6) / 10) ^ 1.1)
      end

      local effective_dist = math.abs(stroke_dist_x) * velocity_gain
      local target_steps = math.floor(effective_dist / step_dist)

      -- Determine maximum possible steps in the current direction
      local max_available = (stroke_dist_x > 0) and info.steps_right or info.steps_left
      target_steps = math.min(target_steps, max_available)

      -- Trigger step if target exceeds steps already taken, paced with minimum interval
      if target_steps > stroke_steps_taken and (now - last_step_time >= MIN_STEP_INTERVAL_MS) then
        if stroke_dist_x > 0 then
          navigate_focus("r")
        else
          navigate_focus("l")
        end
        stroke_steps_taken = stroke_steps_taken + 1
        last_step_time = now
      end
    end,
    finish = function()
      stroke_dist_x = 0
      stroke_steps_taken = 0
      stroke_peak_speed = 0
      stroke_direction = 0
    end,
    ["end"] = function()
      stroke_dist_x = 0
      stroke_steps_taken = 0
      stroke_peak_speed = 0
      stroke_direction = 0
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

