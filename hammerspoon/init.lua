-- ─── WezTerm hotkey window (iTerm-style show/hide) ───────────────────────────
-- WezTerm has no native global hotkey window (wezterm#1751), so Hammerspoon
-- provides the system-wide binding.

-- Enables the `hs` command-line tool to talk to this instance.
require('hs.ipc')

local WEZTERM_BUNDLE_ID = 'com.github.wez.wezterm'

-- Change these two lines to pick a different hotkey.
local HOTKEY_MODS = { 'ctrl' }
local HOTKEY_KEY = 'escape'

-- Follow the mouse to whichever display you are on when showing.
local FOLLOW_TO_ACTIVE_SCREEN = true
local FOLLOW_TO_ACTIVE_SPACE = false
-- Fill the target display instead of carrying over the old, relatively-scaled
-- geometry -- moveToScreen alone shrinks the window when displays differ.
local MAXIMIZE_ON_SHOW = true

-- Pause between the move and the resize so the window server catches up.
local RESIZE_SETTLE_US = 90000
local RESIZE_ATTEMPTS = 6
-- WezTerm snaps to whole character cells, so it may stop a few pixels short.
local CELL_TOLERANCE = 2

-- Snap rather than slide; the default animation makes the move visible.
hs.window.animationDuration = 0

-- The screen you are "on" is the one holding the mouse pointer; keyboard focus
-- is unreliable here because the hotkey fires while another app is frontmost.
local function activeScreen()
   return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

-- A single setFrame() is clamped against the display the window is still on,
-- so a move across monitors lands at the wrong size in both directions:
-- short going to the larger screen, overshooting on the way back. Move first,
-- then re-apply until the geometry sticks -- WezTerm rounds to whole character
-- cells, hence the tolerance rather than an equality test.
local function maximizeOnto(win, screen)
   local f = screen:frame()
   win:setTopLeft(f)

   for _ = 1, RESIZE_ATTEMPTS do
      hs.timer.usleep(RESIZE_SETTLE_US)
      local g = win:frame()
      local settled = g.x == f.x
         and g.y == f.y
         and math.abs(g.w - f.w) <= CELL_TOLERANCE
         and math.abs(g.h - f.h) <= CELL_TOLERANCE
      if settled then
         return
      end
      win:setTopLeft(f)
      win:setSize(f)
   end
end

-- Pull the window onto the display you are using and size it to fit there.
local function followTo(win, screen)
   if win == nil or screen == nil then
      return
   end

   local target = FOLLOW_TO_ACTIVE_SCREEN and screen or win:screen()
   if target == nil then
      return
   end

   if FOLLOW_TO_ACTIVE_SPACE then
      local ok, space = pcall(hs.spaces.activeSpaceOnScreen, target)
      if ok and space then
         -- Fails silently on some setups (SIP, fullscreen windows); the
         -- reframe below still gets the window onto the right display.
         pcall(hs.spaces.moveWindowToSpace, win, space)
      end
   end

   if MAXIMIZE_ON_SHOW then
      -- screen:frame() is the usable area, excluding menu bar and Dock.
      maximizeOnto(win, target)
   elseif win:screen() ~= target then
      win:moveToScreen(target, false, true, 0)
   end
end

hs.hotkey.bind(HOTKEY_MODS, HOTKEY_KEY, function()
   local app = hs.application.get(WEZTERM_BUNDLE_ID)

   if app == nil then
      -- Not running yet: start it.
      hs.application.launchOrFocusByBundleID(WEZTERM_BUNDLE_ID)
      return
   end

   if app:isFrontmost() then
      app:hide()
   else
      -- Unhide, raise, and focus a window. launchOrFocus alone can leave the
      -- app active with no window raised if it was hidden.
      local screen = activeScreen()
      app:unhide()
      hs.application.launchOrFocusByBundleID(WEZTERM_BUNDLE_ID)
      local win = app:mainWindow() or app:allWindows()[1]
      if win then
         followTo(win, screen)
         win:focus()
      end
   end
end)

-- Reload this config with ctrl+alt+cmd+R
hs.hotkey.bind({ 'ctrl', 'alt', 'cmd' }, 'R', function()
   hs.reload()
end)

hs.alert.show('Hammerspoon config loaded')
