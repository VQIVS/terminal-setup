# wezterm + hammerspoon + ghostty

My macOS terminal setup: a [WezTerm](https://wezterm.org) config, the
[Hammerspoon](https://www.hammerspoon.org) script that gives it a global
show/hide hotkey, and a [Ghostty](https://ghostty.org) config for the one
thing that pair provably cannot do (see [Ghostty](#ghostty)).

The parts are separate programs but they solve one problem together — a
terminal that is always one keypress away, always on the display I'm looking
at, and always full-screen there.

```
wezterm/wezterm.lua     -> ~/.config/wezterm/wezterm.lua
hammerspoon/init.lua    -> ~/.hammerspoon/init.lua
ghostty/config          -> ~/.config/ghostty/config
ghostty/backdrop.sh     -> ~/.config/ghostty/backdrop.sh
```

## WezTerm

**Font.** MesloLGS Nerd Font Mono with explicit `font_rules` for bold, italic,
and bold-italic, so WezTerm uses the real installed faces instead of
synthesising a slant. Falls back to Symbols Nerd Font and Apple Color Emoji.

**Theme.** Catppuccin Mocha at 70% window opacity.

**Backdrops.** A wallpaper is drawn behind the text, picked at random from a
list at launch, with `CMD+SHIFT+B` cycling to the next one. Two layers are
composited: the image (desaturated and dimmed via `hsb`, `attachment = 'Fixed'`
so it doesn't scroll with the viewport) and a `#11111b` scrim at 55% on top of
it. The scrim is the part that matters — even dark wallpapers have bright
regions, and without it text over those regions becomes unreadable.

The candidate list is only the dark frames from `backdrops/`, selected by mean
greyscale luminance with the cutoff at 0.30 (the folder split cleanly there:
brightest kept image was 0.29, next one up 0.40). Lighter frames wash out
Mocha's foreground.

> The `backdrops/` images themselves are **not in this repo** — they're
> third-party wallpapers and ~21MB. Drop your own JPEG/PNGs into
> `~/.config/wezterm/backdrops/` and edit the `BACKDROPS` list in
> `wezterm.lua` to match. Anything unlisted is simply ignored.

**Multi-monitor.** The interesting part of the config. `wezterm.gui.screens()`
only works on the GUI thread, so screen queries live inside key callbacks and
the `gui-startup` event rather than at config-load time. Screens are sorted
left-to-right then top-to-bottom, so "next screen" follows the physical layout.

Moving a window to another display is a two-step dance: `maximize()` is
relative to whichever display the window currently sits on, so repositioning
and maximizing in the same tick maximizes back onto the *old* screen. The
config repositions, waits 200ms, then maximizes. A 40px inset keeps the window
off the shared edge between displays — with mixed scale factors, a window
sitting exactly on the boundary can be attributed to the neighbour and
maximize on the wrong monitor.

New windows start maximized on the active display via `gui-startup`.
`maximize()` is used rather than `set_inner_size()` because the latter takes
pixels while screen dimensions are in points, which under-sizes on Retina.

**Keys.**

| Binding | Action |
| --- | --- |
| `CMD+Enter` | Toggle fullscreen (macOS claims F11 for Show Desktop) |
| `CMD+SHIFT+Enter` | Throw this window to the next display |
| `CMD+SHIFT+N` | New window on the next display, same workspace and cwd |
| `CMD+D` / `CMD+SHIFT+D` | Split horizontal / vertical |
| `CMD+W` | Close pane, no confirmation |
| `CMD+ALT+arrows` | Move between panes |
| `CMD+SHIFT+B` | Next backdrop |
| `CMD+K` | Clear scrollback and viewport |
| `CMD+F` | Search |
| `CMD+SHIFT+P` | Command palette |
| `CMD+left/right` | Home / End |
| `CMD+Backspace` | Delete to start of line |

Also: bottomless-ish 10k scrollback, no scrollbar, no audible bell, blinking
bar cursor, `RESIZE`-only window decorations, tab bar hidden when there's one
tab.

## Hammerspoon

WezTerm has no native global hotkey window ([wezterm#1751]), so Hammerspoon
supplies one. **`Ctrl+Escape`** toggles WezTerm: hide it if it's frontmost,
otherwise unhide, raise, focus, and pull it onto the display you're using.
`Ctrl+Alt+Cmd+R` reloads the Hammerspoon config.

"The display you're using" is the one holding the **mouse pointer**, not the
one with keyboard focus — the hotkey fires while another app is frontmost, so
focus is unreliable at that moment.

The resize is a retry loop, and that's deliberate. A single `setFrame()` is
clamped against the display the window is still on, so a cross-monitor move
lands at the wrong size in both directions: short going to the larger screen,
overshooting on the way back. So it moves first, then re-applies position and
size up to 6 times with 90ms between attempts, until the geometry sticks.
WezTerm snaps to whole character cells, so the settle check uses a 2px
tolerance rather than an equality test.

Knobs at the top of the file: `HOTKEY_MODS` / `HOTKEY_KEY`,
`FOLLOW_TO_ACTIVE_SCREEN`, `FOLLOW_TO_ACTIVE_SPACE` (off by default — space
moves fail silently under SIP on some setups; the reframe still gets the
window to the right display), and `MAXIMIZE_ON_SHOW`.

`hs.ipc` is required so the `hs` command-line tool can talk to the running
instance.

[wezterm#1751]: https://github.com/wez/wezterm/issues/1751

## Ghostty

**Why a second terminal.** Hammerspoon can show WezTerm over anything *except*
a natively full-screened app. macOS gives such a window its own exclusive
Space, and only windows the owning app created as floating panels
(`NSPanel` + `canJoinAllSpaces`) may be drawn into one. Hammerspoon drives
other apps through the Accessibility API, which has no window-level or
collection-behaviour setter, so the flag cannot be retrofitted:
`hs.spaces.moveWindowToSpace(weztermWin, fullscreenSpace, true)` returns
`true` and `hs.spaces.windowSpaces()` then shows the window still on its old
Space. The API says as much — *"even then it works for floating windows
only."*

So the choice is: switch Space, un-full-screen the app underneath, or use a
terminal that makes the panel itself. Ghostty's **quick terminal** is that
panel — Yakuake/ddterm behaviour, drawn over a full-screen VS Code without
moving it or leaving the Space ([fixed in Ghostty 1.1][gt-3719]).

**Hotkey.** `Ctrl+T`, as `keybind = global:ctrl+t=toggle_quick_terminal`. The
`global:` prefix is what makes it fire while another app is frontmost, and it
needs Accessibility permission. It also means `Ctrl+T` is swallowed
system-wide, including inside terminals — worth knowing if you use fzf's
`Ctrl+T` widget or readline's transpose-chars.

`quick-terminal-space-behavior = remain` pins it to the desktop it opened on,
`quick-terminal-screen = mouse` drops it onto the display holding the pointer
(same rule Hammerspoon uses), and `autohide` dismisses it the moment focus
leaves.

**Look.** Matched to the WezTerm side: MesloLGS Nerd Font Mono 14, Catppuccin
Mocha, 70% opacity, plus `background-blur` since this panel sits over live
application pixels rather than a desktop.

**Backdrops.** Ghostty takes a single static `background-image` and has no
scripting hook, so the rotation WezTerm does in Lua lives in `backdrop.sh`
instead. It writes the `background-image*` lines into a generated
`backdrop.conf`, which `config` pulls in via `config-file = ?backdrop.conf`
(the `?` keeps a fresh checkout with no wallpapers from erroring).

```sh
~/.config/ghostty/backdrop.sh next     # or prev | random | <filename>
```

Ghostty re-reads config on `CMD+SHIFT+,`; `--reload` presses that for you via
System Events if you'd rather not.

The script reads the *same* `~/.config/wezterm/backdrops/` folder and the same
11-name dark-frames list, so both terminals draw from one set of wallpapers.
With no layer stack to work with, the WezTerm recipe (image dimmed to
`brightness = 0.10`, then a `#11111b` scrim at 55% over it) collapses into a
single `background-image-opacity = 0.18` blend against the theme background —
same end state: dark enough that a bright patch of wallpaper can't eat the
foreground. `background-image-fit = cover` rather than `contain`, because a
letterboxed image would show bare background colour down the sides of a
full-width drop-down.

[gt-3719]: https://github.com/ghostty-org/ghostty/discussions/3719

## Install

```sh
git clone https://github.com/VQIVS/wezterm-hammerspoon.git
cd wezterm-hammerspoon
./install.sh
```

`install.sh` symlinks all the configs into place, backing up anything already
there, copies [MesloLGS Nerd Font] from `fonts/` into `~/Library/Fonts/`, and
seeds a Ghostty backdrop. Then grant Accessibility permission in System
Settings → Privacy & Security to **Hammerspoon** (for `Ctrl+Escape`) and to
**Ghostty** (for `Ctrl+T`).

WezTerm and Ghostty are not installed by the script:

```sh
brew install --cask wezterm ghostty
```

[MesloLGS Nerd Font]: https://github.com/ryanoasis/nerd-fonts/releases/latest
