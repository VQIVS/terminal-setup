local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- ─── font ────────────────────────────────────────────────────────────────────
config.font = wezterm.font_with_fallback({
   'MesloLGS Nerd Font Mono',
   'Symbols Nerd Font Mono',
   'Apple Color Emoji',
})
-- Real italic/bold faces are installed, so let them be used rather than
-- having WezTerm synthesise a slant.
config.font_rules = {
   {
      italic = true,
      intensity = 'Normal',
      font = wezterm.font({ family = 'MesloLGS Nerd Font Mono', style = 'Italic' }),
   },
   {
      italic = true,
      intensity = 'Bold',
      font = wezterm.font({ family = 'MesloLGS Nerd Font Mono', weight = 'Bold', style = 'Italic' }),
   },
   {
      italic = false,
      intensity = 'Bold',
      font = wezterm.font({ family = 'MesloLGS Nerd Font Mono', weight = 'Bold' }),
   },
}
config.font_size = 14
config.line_height = 1.0
config.underline_thickness = '1.5pt'

-- ─── theme ───────────────────────────────────────────────────────────────────
config.color_scheme = 'Catppuccin Mocha'

-- ─── background ──────────────────────────────────────────────────────────────
config.window_background_opacity = .7

local BACKDROP_DIR = wezterm.config_dir .. '/backdrops/'

-- Only the dark frames from backdrops/. Selected by mean greyscale luminance
-- with the cutoff at 0.30, where the folder happens to split cleanly: the
-- brightest kept image measures 0.29 and the next one up jumps to 0.40. The
-- lighter frames wash out Catppuccin Mocha's foreground, so they stay out.
local BACKDROPS = {
   'astro-jelly.jpg',    -- 0.10
   'totoro.jpeg',        -- 0.14
   '6798923.jpg',        -- 0.15
   'space.jpg',          -- 0.17
   'voyage.jpg',         -- 0.18
   'sword.jpg',          -- 0.20
   '4356396.jpg',        -- 0.22
   'cloudy-quasar.png',  -- 0.23
   '5-cm.jpg',           -- 0.25
   'cherry-lava.jpg',    -- 0.28
   'nord-space.png',     -- 0.29
}

-- Later layers draw on top, so the scrim goes after the image. Even the dark
-- frames have bright regions, and the scrim is what keeps text readable there
-- rather than relying on the wallpaper being uniformly dim.
local function backdrop_layers(name)
   return {
      {
         source = { File = BACKDROP_DIR .. name },
         horizontal_align = 'Center',
         vertical_align = 'Middle',
         -- Fixed: the image stays put instead of scrolling with the viewport.
         attachment = 'Fixed',
         hsb = { hue = 1.0, saturation = 0.85, brightness = 0.10 },
      },
      {
         source = { Color = '#11111b' },  -- Catppuccin Mocha crust
         width = '100%',
         height = '100%',
         opacity = 0.55,
      },
   }
end

-- Start on a different frame each launch. GLOBAL survives config reloads, so
-- the cycle key below picks up where it left off rather than jumping around.
math.randomseed(os.time())
wezterm.GLOBAL.backdrop_index = wezterm.GLOBAL.backdrop_index or math.random(#BACKDROPS)
config.background = backdrop_layers(BACKDROPS[wezterm.GLOBAL.backdrop_index])

-- ─── window ──────────────────────────────────────────────────────────────────
config.window_decorations = 'RESIZE'
config.window_close_confirmation = 'NeverPrompt'
config.adjust_window_size_when_changing_font_size = false
config.window_padding = { left = 12, right = 12, top = 10, bottom = 8 }
config.native_macos_fullscreen_mode = false

-- ─── tabs ────────────────────────────────────────────────────────────────────
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.tab_max_width = 28

-- ─── cursor / perf ───────────────────────────────────────────────────────────
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 600
config.animation_fps = 60
config.max_fps = 120
config.scrollback_lines = 10000
config.enable_scroll_bar = false
config.audible_bell = 'Disabled'

-- ─── multi-monitor helpers ───────────────────────────────────────────────────
-- wezterm.gui.screens() only works on the GUI thread, so these are called from
-- key callbacks / gui-startup rather than at config-load time.
local function ordered_screens()
   local info = wezterm.gui.screens()
   local list = {}
   for _, s in pairs(info.by_name) do
      table.insert(list, s)
   end
   -- left-to-right, then top-to-bottom, so "next" follows physical layout
   table.sort(list, function(a, b)
      if a.x ~= b.x then
         return a.x < b.x
      end
      return a.y < b.y
   end)
   return list, info
end

-- The screen after the focused one, wrapping around. With a single display
-- this returns that display, so the bindings stay harmless on the laptop alone.
local function next_screen()
   local list, info = ordered_screens()
   local current = info.active or info.main
   if #list < 2 or not current then
      return current or list[1]
   end
   for i, s in ipairs(list) do
      if s.name == current.name then
         return list[(i % #list) + 1]
      end
   end
   return list[1]
end

-- Move a window onto `screen` and fill it. maximize() is relative to whichever
-- display the window sits on, so it has to run after the reposition lands —
-- doing both in one tick maximizes back onto the old screen.
-- The inset keeps the window off the shared edge between displays: the two
-- screens here run at different scale factors, and a window sitting exactly on
-- the boundary can get attributed to the neighbour and maximize on the wrong one.
local function place_on(gui_window, screen)
   if not (gui_window and screen) then
      return
   end
   gui_window:set_position(screen.x + 40, screen.y + 40)
   wezterm.time.call_after(0.2, function()
      gui_window:maximize()
   end)
end

-- ─── keys ────────────────────────────────────────────────────────────────────
local act = wezterm.action
config.keys = {
   -- macOS claims F11 for Show Desktop, so use a combo it does not intercept.
   { key = 'Enter', mods = 'CMD', action = act.ToggleFullScreen },

   -- monitors: throw this window to the next display, or open a second window
   -- joined to the same workspace over there (same mux session, new tab).
   {
      key = 'Enter',
      mods = 'CMD|SHIFT',
      action = wezterm.action_callback(function(window)
         place_on(window:gui_window(), next_screen())
      end),
   },
   {
      key = 'n',
      mods = 'CMD|SHIFT',
      action = wezterm.action_callback(function(window, pane)
         local cwd = pane:get_current_working_dir()
         local _, _, new_window = wezterm.mux.spawn_window({
            workspace = window:active_workspace(),
            cwd = cwd and cwd.file_path or nil,
         })
         place_on(new_window:gui_window(), next_screen())
      end),
   },

   -- panes
   { key = 'd', mods = 'CMD', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
   { key = 'd', mods = 'CMD|SHIFT', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
   { key = 'w', mods = 'CMD', action = act.CloseCurrentPane({ confirm = false }) },
   { key = 'LeftArrow', mods = 'CMD|ALT', action = act.ActivatePaneDirection('Left') },
   { key = 'RightArrow', mods = 'CMD|ALT', action = act.ActivatePaneDirection('Right') },
   { key = 'UpArrow', mods = 'CMD|ALT', action = act.ActivatePaneDirection('Up') },
   { key = 'DownArrow', mods = 'CMD|ALT', action = act.ActivatePaneDirection('Down') },

   -- backdrop: step to the next dark wallpaper in this window
   {
      key = 'b',
      mods = 'CMD|SHIFT',
      action = wezterm.action_callback(function(window)
         local i = (wezterm.GLOBAL.backdrop_index % #BACKDROPS) + 1
         wezterm.GLOBAL.backdrop_index = i
         local overrides = window:get_config_overrides() or {}
         overrides.background = backdrop_layers(BACKDROPS[i])
         window:set_config_overrides(overrides)
      end),
   },

   -- misc
   { key = 'k', mods = 'CMD', action = act.ClearScrollback('ScrollbackAndViewport') },
   { key = 'f', mods = 'CMD', action = act.Search({ CaseInSensitiveString = '' }) },
   { key = 'p', mods = 'CMD|SHIFT', action = act.ActivateCommandPalette },

   -- readline-ish niceties
   { key = 'LeftArrow', mods = 'CMD', action = act.SendString('\x1bOH') },
   { key = 'RightArrow', mods = 'CMD', action = act.SendString('\x1bOF') },
   { key = 'Backspace', mods = 'CMD', action = act.SendString('\x15') },
}

-- ─── start maximized ─────────────────────────────────────────────────────────
-- maximize() is DPI-correct; set_inner_size() takes pixels while screen dims
-- are in points, which under-sizes the window on Retina displays.
wezterm.on('gui-startup', function(cmd)
   local _, _, window = wezterm.mux.spawn_window(cmd or {})
   local _, info = ordered_screens()
   place_on(window:gui_window(), info.active or info.main)
end)

return config
