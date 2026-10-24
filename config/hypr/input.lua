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

-- Navigate focus between windows on the active workspace with extra right shift support
local ws_extra_shift = {}
local navigate_focus
local function navigate_focus_dispatch(dir)
  if navigate_focus then
    navigate_focus(dir)
  else
    hl.dispatch(hl.dsp.focus({ direction = dir }))
  end
end

_G.navigate_focus = navigate_focus_dispatch

-- Toggle window between normal column width and fullscreen width (1.0),
-- inflating to push adjacent windows aside in scrolling layout instead of hiding them.
local previous_window_states = {}

local function toggle_fullscreen_inflate()
  local win = hl.get_active_window()
  if not win then return end

  -- If in extra-shifted state, un-shift first
  local cur_ws_id = win.workspace and win.workspace.id
  if cur_ws_id and ws_extra_shift[cur_ws_id] then
    local shift_info = ws_extra_shift[cur_ws_id]
    if shift_info and shift_info.state == "full" then
      if shift_info.was_half then
        local shift = shift_info.shift or 960
        hl.dispatch(hl.dsp.layout(string.format("move +%d", shift * 2)))
      else
        hl.dispatch(hl.dsp.layout("move -col"))
      end
    elseif shift_info and shift_info.state == "half" then
      local shift = (shift_info and shift_info.shift) or 960
      hl.dispatch(hl.dsp.layout(string.format("move +%d", shift)))
    end
    ws_extra_shift[cur_ws_id] = nil
  end

  -- If floating or in native fullscreen, use normal fullscreen toggle
  if win.floating or (win.fullscreen and win.fullscreen ~= 0) then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))
    return
  end

  local mon = hl.get_active_monitor()
  local mon_width = (mon and mon.width) or 1920

  -- If already taking up roughly the full screen width (>= 85%)
  if win.size and win.size.x and win.size.x >= mon_width * 0.85 then
    local state = previous_window_states[win.address] or { width = 0.5, at_x = 0 }
    previous_window_states[win.address] = nil

    local target_width = state.width or 0.5
    -- Guarantee half width if it was around half or previously compressed to a third
    if target_width >= 0.30 and target_width <= 0.55 then
      target_width = 0.5
    end

    hl.dispatch(hl.dsp.layout("colresize " .. string.format("%.2f", target_width)))

    local cur_win = hl.get_active_window()
    local cur_x = (cur_win and cur_win.at and cur_win.at.x) or 0
    local shift = (state.at_x or 0) - cur_x
    if shift ~= 0 then
      hl.dispatch(hl.dsp.layout(string.format("move %+d", shift)))
    end
  else
    local current_ratio = (win.size and win.size.x and mon_width > 0) and (win.size.x / mon_width) or 0.5
    if math.abs(current_ratio - 0.5) < 0.08 then
      current_ratio = 0.5
    end
    local current_at_x = (win.at and win.at.x) or 0
    previous_window_states[win.address] = {
      width = current_ratio,
      at_x = current_at_x,
    }
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
local stroke_target_steps = 0
local stroke_peak_speed = 0
local stroke_direction = 0 -- 1 for right, -1 for left
local stroke_anchor_left = 0
local stroke_anchor_right = 0
local last_step_time = 0
local momentum_session = 0

-- Match Hyprland workspace swipe parameters (workspace_swipe_distance = 350, scale = 1.1)
local SWIPE_DISTANCE = 318 -- 350 / 1.1
local MIN_SPEED_TO_FORCE = 5 -- matches workspace_swipe_min_speed_to_force
local CANCEL_RATIO = 0.1 -- matches workspace_swipe_cancel_ratio
local COMMIT_THRESHOLD = SWIPE_DISTANCE * CANCEL_RATIO -- ~32px
local NOISE_DEADZONE = 15
local MIN_STEP_INTERVAL_MS = 75
local MOMENTUM_INTERVAL_MS = 85

local function get_window_is_fullscreen(win, mon_width)
  if not win then return false end
  if win.fullscreen and win.fullscreen ~= 0 then return true end
  if win.size and win.size.x and mon_width and mon_width > 0 then
    if win.size.x >= mon_width * 0.85 then
      return true
    end
  end
  return false
end

local function get_extra_shift_amount(win, mon_width)
  if get_window_is_fullscreen(win, mon_width) then
    return mon_width -- fullscreen: go an entire window to the right
  else
    return math.floor(mon_width * 0.5) -- two halves: go a half extra to the right
  end
end

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
    if ax ~= bx then
      return ax < bx
    end
    local ay = (a.at and a.at.y) or 0
    local by = (b.at and b.at.y) or 0
    return ay < by
  end)

  local mon = hl.get_active_monitor()
  local mon_width = (mon and mon.width) or 1920

  local rightmost = (#ws_windows > 0) and ws_windows[#ws_windows] or nil
  local is_fs = rightmost and get_window_is_fullscreen(rightmost, mon_width)

  -- Check if workspace is currently extra-shifted to the right:
  local shift_state = "none"
  local shift_info = cur_ws_id and ws_extra_shift[cur_ws_id]
  if shift_info and #ws_windows > 0 and rightmost and rightmost.address == shift_info.address then
    shift_state = shift_info.state or "half"
  else
    if cur_ws_id then ws_extra_shift[cur_ws_id] = nil end
    shift_info = nil
  end

  local is_shifted = (shift_state ~= "none")
  local cur_idx = is_shifted and #ws_windows or 1
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

  local steps_right = 0
  local steps_left = 0

  if shift_state == "full" then
    steps_right = 0
    if shift_info and shift_info.was_half then
      steps_left = (#ws_windows - 1) + 2
    else
      steps_left = (#ws_windows - 1) + 1
    end
  elseif shift_state == "half" then
    steps_right = 1
    steps_left = (#ws_windows - 1) + 1
  else
    local extra_available = (#ws_windows > 0) and (is_fs and 1 or 2) or 0
    steps_right = math.max(0, #ws_windows - cur_idx) + extra_available
    steps_left = cur_idx - 1
  end

  return {
    cur_idx = cur_idx,
    total_windows = #ws_windows,
    total_items = total_items,
    steps_left = steps_left,
    steps_right = steps_right,
    ws_id = cur_ws_id,
    ws_windows = ws_windows,
    cur_win = cur,
    mon_width = mon_width,
    is_shifted = is_shifted,
    shift_state = shift_state,
    shift_info = shift_info,
  }
end

navigate_focus = function(dir)
  local info = get_layout_info()
  local cur_ws_id = info.ws_id
  local ws_windows = info.ws_windows or {}
  local mon_width = info.mon_width or 1920
  local shift_info = cur_ws_id and ws_extra_shift[cur_ws_id]
  local rightmost_win = ws_windows[#ws_windows] or info.cur_win
  local is_fs = get_window_is_fullscreen(rightmost_win, mon_width)

  if dir == "r" then
    if shift_info and shift_info.state == "full" then
      -- Boundary reached
      return
    elseif shift_info and shift_info.state == "half" then
      -- Transition from half-shifted to full-shifted:
      -- User was at "half app half screen", swiped right again -> go an entire window to the right!
      hl.dispatch(hl.dsp.layout("move +col"))
      if cur_ws_id and rightmost_win then
        ws_extra_shift[cur_ws_id] = {
          state = "full",
          was_half = true,
          shift = shift_info.shift or math.floor(mon_width * 0.5),
          address = rightmost_win.address,
        }
      end
    elseif #ws_windows > 0 and info.cur_idx >= #ws_windows then
      -- At rightmost window, take extra step right
      if is_fs then
        -- Explicitly lock rightmost window's column width to 1.0 before moving right into empty space.
        -- This guarantees Hyprland will not collapse it to default 0.5 when a new app is spawned.
        hl.dispatch(hl.dsp.layout("colresize 1.00"))
        hl.dispatch(hl.dsp.layout("move +col"))
        if cur_ws_id and rightmost_win then
          ws_extra_shift[cur_ws_id] = {
            state = "full",
            was_half = false,
            address = rightmost_win.address,
          }
        end
      else
        local shift = math.floor(mon_width * 0.5)
        hl.dispatch(hl.dsp.layout(string.format("move -%d", shift)))
        if cur_ws_id and rightmost_win then
          ws_extra_shift[cur_ws_id] = {
            state = "half",
            was_half = true,
            shift = shift,
            address = rightmost_win.address,
          }
        end
      end
    else
      -- Normal move focus right
      hl.dispatch(hl.dsp.focus({ direction = "r" }))
      local next_win = ws_windows[info.cur_idx + 1]
      if next_win and get_window_is_fullscreen(next_win, mon_width) then
        hl.dispatch(hl.dsp.layout("fit active"))
      end
    end

  elseif dir == "l" then
    if shift_info and shift_info.state == "full" then
      if shift_info.was_half then
        -- Return from full to half!
        local shift = shift_info.shift or math.floor(mon_width * 0.5)
        hl.dispatch(hl.dsp.layout(string.format("move +%d", shift)))
        ws_extra_shift[cur_ws_id] = {
          state = "half",
          was_half = true,
          shift = shift,
          address = rightmost_win.address,
        }
        if rightmost_win and rightmost_win.address then
          hl.dispatch(hl.dsp.focus({ window = "address:" .. rightmost_win.address }))
        end
      else
        -- Was fullscreen: return from full to normal
        hl.dispatch(hl.dsp.layout("move -col"))
        ws_extra_shift[cur_ws_id] = nil
        if rightmost_win and rightmost_win.address then
          hl.dispatch(hl.dsp.focus({ window = "address:" .. rightmost_win.address }))
        end
      end
    elseif shift_info and shift_info.state == "half" then
      -- Return from half to normal
      local shift = shift_info.shift or math.floor(mon_width * 0.5)
      hl.dispatch(hl.dsp.layout(string.format("move +%d", shift)))
      ws_extra_shift[cur_ws_id] = nil
      if rightmost_win and rightmost_win.address then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. rightmost_win.address }))
      end
    elseif info.cur_idx > 1 then
      -- Move focus left
      hl.dispatch(hl.dsp.focus({ direction = "l" }))
      local prev_win = ws_windows[info.cur_idx - 1]
      if prev_win and get_window_is_fullscreen(prev_win, mon_width) then
        hl.dispatch(hl.dsp.layout("fit active"))
      end
    else
      -- At leftmost window: do not wrap around
      return
    end
  end
end

local function handle_stroke_end()
  local dir = stroke_direction > 0 and "r" or "l"
  local remaining_steps = stroke_target_steps - stroke_steps_taken

  if remaining_steps > 0 and stroke_direction ~= 0 then
    local session = momentum_session
    local function run_momentum(remaining)
      if remaining <= 0 then return end
      hl.timer(function()
        if session ~= momentum_session then return end
        navigate_focus(dir)
        run_momentum(remaining - 1)
      end, { timeout = MOMENTUM_INTERVAL_MS, type = "oneshot" })
    end
    run_momentum(remaining_steps)
  end

  stroke_dist_x = 0
  stroke_steps_taken = 0
  stroke_target_steps = 0
  stroke_peak_speed = 0
  stroke_direction = 0
  stroke_anchor_left = 0
  stroke_anchor_right = 0
  last_step_time = 0
end

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = {
    start = function()
      -- Cancel any active momentum from a previous flick
      momentum_session = momentum_session + 1

      stroke_dist_x = 0
      stroke_steps_taken = 0
      stroke_target_steps = 0
      stroke_peak_speed = 0
      stroke_direction = 0
      last_step_time = 0

      local info = get_layout_info()
      stroke_anchor_left = info.steps_left
      stroke_anchor_right = info.steps_right
    end,
    update = function(e)
      if not (e and e.delta and e.delta.x) then return end
      local dx = e.delta.x
      local now = (e and e.time_ms) or (os.clock() * 1000)
      local speed = math.abs(dx)

      -- Decay peak speed gently over time so resting fingers return to 1:1 drag
      stroke_peak_speed = math.max(speed, stroke_peak_speed * 0.92)

      -- Turnaround detection: if user reverses direction, reset stroke accumulation and re-anchor
      if (stroke_direction > 0 and dx < -2) or (stroke_direction < 0 and dx > 2) then
        stroke_dist_x = 0
        stroke_steps_taken = 0
        stroke_target_steps = 0
        stroke_peak_speed = speed
        stroke_direction = dx > 0 and 1 or -1
        local info = get_layout_info()
        stroke_anchor_left = info.steps_left
        stroke_anchor_right = info.steps_right
      elseif stroke_direction == 0 and math.abs(dx) > 1 then
        stroke_direction = dx > 0 and 1 or -1
      end

      stroke_dist_x = stroke_dist_x + dx
      local abs_dist = math.abs(stroke_dist_x)

      -- Ignore minor noise under deadzone
      if abs_dist < NOISE_DEADZONE and stroke_peak_speed < MIN_SPEED_TO_FORCE then
        return
      end

      -- Match Hyprland workspace swipe logic:
      -- Commit step if distance exceeds cancel_ratio threshold (~32px) OR if speed exceeds min_speed_to_force (5)
      local target_steps = 0
      if abs_dist >= COMMIT_THRESHOLD or stroke_peak_speed >= MIN_SPEED_TO_FORCE then
        target_steps = 1 + math.floor(math.max(0, abs_dist - COMMIT_THRESHOLD) / SWIPE_DISTANCE)
      end

      local max_available = (stroke_dist_x > 0) and stroke_anchor_right or stroke_anchor_left
      target_steps = math.min(target_steps, max_available)
      stroke_target_steps = target_steps

      -- Fire steps during contact if target exceeds steps taken, paced at MIN_STEP_INTERVAL_MS
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
    finish = handle_stroke_end,
    ["end"] = handle_stroke_end,
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

-- Automatically size newly spawned apps so they always cover the available empty screen:
-- 1. Full empty screen (swiped right an entire window, or empty workspace) -> covers entire screen (1.0).
-- 2. Half empty screen (terminal on half screen, or swiped right half a window) -> covers other half (0.5).
local spawn_timers = {}
local function set_spawn_timer(fn, timeout)
  local t
  t = hl.timer(function()
    spawn_timers[t] = nil
    fn()
  end, { type = "oneshot", timeout = timeout or 25 })
  spawn_timers[t] = true
  return t
end

local function handle_window_spawned(win)
  if not win then
    win = hl.get_active_window()
  end
  if not win or win.floating then return end

  local win_ws_id = win.workspace and win.workspace.id
  if not win_ws_id then
    local ws = hl.get_active_workspace()
    win_ws_id = ws and ws.id
  end

  local shift_info = win_ws_id and ws_extra_shift[win_ws_id]
  local mon = hl.get_active_monitor()
  local mon_width = (mon and mon.width) or 1920

  local target_ratio = nil
  local fit_method = "fit active"
  local prev_win_addr = nil

  if shift_info and shift_info.state == "full" then
    target_ratio = 1.0
    fit_method = "fit active"
    prev_win_addr = shift_info.address
  elseif shift_info and shift_info.state == "half" then
    target_ratio = 0.5
    fit_method = "fit toend"
  else
    local all_windows = hl.get_windows() or {}
    local ws_windows = {}
    for _, w in ipairs(all_windows) do
      if w and w.workspace and w.workspace.id == win_ws_id and not w.floating and not w.pinned and w.address ~= win.address then
        table.insert(ws_windows, w)
      end
    end

    table.sort(ws_windows, function(a, b)
      local ax = (a.at and a.at.x) or 0
      local bx = (b.at and b.at.x) or 0
      if ax ~= bx then return ax < bx end
      return (a.at.y or 0) < (b.at.y or 0)
    end)

    if #ws_windows == 0 then
      target_ratio = 1.0
      fit_method = "fit active"
    else
      local last_w = ws_windows[#ws_windows]
      if get_window_is_fullscreen(last_w, mon_width) then
        target_ratio = 1.0
        fit_method = "fit active"
        prev_win_addr = last_w.address
      else
        target_ratio = 0.5
        fit_method = "fit toend"
      end
    end
  end

  if win_ws_id then
    ws_extra_shift[win_ws_id] = nil
  end

  if target_ratio then
    local win_addr = win.address
    local function apply_resize()
      if prev_win_addr then
        local pw = hl.get_window("address:" .. prev_win_addr)
        if pw and not pw.floating then
          local p_ratio = (pw.size and pw.size.x and mon_width > 0) and (pw.size.x / mon_width) or 0
          if math.abs(p_ratio - 1.0) > 0.08 then
            hl.dispatch(hl.dsp.focus({ window = "address:" .. prev_win_addr }))
            hl.dispatch(hl.dsp.layout("colresize 1.00"))
          end
        end
      end

      if win_addr then
        local w = hl.get_window("address:" .. win_addr)
        if w and not w.floating then
          local mon_w = mon_width
          local cur_ratio = (w.size and w.size.x and mon_w > 0) and (w.size.x / mon_w) or 0
          if target_ratio == 1.0 or math.abs(cur_ratio - target_ratio) > 0.08 then
            hl.dispatch(hl.dsp.focus({ window = "address:" .. win_addr }))
            hl.dispatch(hl.dsp.layout(string.format("colresize %.2f", target_ratio)))
            hl.dispatch(hl.dsp.layout(fit_method))
          end
        end
      end
    end

    set_spawn_timer(apply_resize, 80)
    set_spawn_timer(apply_resize, 200)
  end
end

update_persistent_workspaces()

hl.on("window.open", function(window)
  if is_collapsing then return end
  handle_window_spawned(window)
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

