# wezterm + hammerspoon + ghostty

My macOS terminal setup: a [WezTerm](https://wezterm.org) config, the
[Hammerspoon](https://www.hammerspoon.org) script that gives it a global
show/hide hotkey, a [Ghostty](https://ghostty.org) config for the one thing
that pair provably cannot do (see [Ghostty](#ghostty)), and the shell and
editors that live inside them — zsh in vi mode, vim and neovim themed to
match.

The parts are separate programs but they solve one problem together — a
terminal that is always one keypress away, always on the display I'm looking
at, and always full-screen there.

```
wezterm/wezterm.lua     -> ~/.config/wezterm/wezterm.lua
hammerspoon/init.lua    -> ~/.hammerspoon/init.lua
ghostty/config          -> ~/.config/ghostty/config
ghostty/backdrop.sh     -> ~/.config/ghostty/backdrop.sh
zsh/zshrc               -> ~/.zshrc
zsh/p10k.zsh            -> ~/.p10k.zsh
zsh/vi-mode.zsh            (sourced out of the repo by zshrc)
vim/vimrc               -> ~/.vimrc
vim/colors/*.vim        -> ~/.vim/colors/
nvim/init.lua           -> ~/.config/nvim/init.lua
nvim/lazy-lock.json     -> ~/.config/nvim/lazy-lock.json
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

**Keys.** Mirrors the WezTerm bindings where Ghostty has an equivalent.

| Binding | Action |
| --- | --- |
| `CMD+D` / `CMD+SHIFT+D` | Split right / down |
| `CMD+H/J/K/L`, `CMD+ALT+arrows` | Move between splits |
| `CMD+CTRL+H/J/K/L` | Resize the focused split |
| `CMD+Enter` | Zoom the focused split |
| `CMD+SHIFT+E` | Equalize splits |
| `CMD+T` / `CMD+W` / `CMD+SHIFT+W` | New tab / close surface / close tab |
| `CMD+SHIFT+left/right` | Previous / next tab |
| `CMD+=` `CMD+-` `CMD+0` | Font size up / down / reset |
| `CMD+F` | Search |
| `CMD+SHIFT+K` | Clear screen (`CMD+K` is a split move here) |
| `CMD+SHIFT+P` | Command palette |
| `CMD+SHIFT+,` | Reload config |
| `CMD+SHIFT+S` | Dump the scrollback to a file and open it in `$EDITOR` |

**Vim mode.** Ghostty has no built-in vi mode for the scrollback, but 1.3 added
[key tables], which is enough to build one. `Ctrl+Shift+Space` activates the
`vimmode` table, where plain keys are motions instead of input to the shell;
`Esc`, `i`, `q` or `Ctrl+C` leave it. Lookup proceeds from the innermost table
outward, so the `CMD+...` bindings above still work while it's active — only
the bare letters are captured.

| In `vimmode` | Does |
| --- | --- |
| `j` / `k` | Scroll a line |
| `d` / `u`, `Ctrl+D` / `Ctrl+U` | Half page |
| `Ctrl+F` / `Ctrl+B` | Full page |
| `gg` / `G` | Top / bottom |
| `[` `]`, `K` `J` | Jump to previous / next shell prompt |
| `/`, `n` / `N` | Search, next / previous match |
| `y` / `p` / `v` | Copy selection / paste / select all |

Prompt jumping needs shell integration, which Ghostty injects into zsh on its
own — nothing to add to `zshrc`.

`keybind = vimmode/` (a table name with no binding) clears the table first, so
reloading the config doesn't stack duplicate bindings.

[key tables]: https://ghostty.org/docs/config/keybind
[gt-3719]: https://github.com/ghostty-org/ghostty/discussions/3719

## Shell

`zsh/zshrc` is the whole thing — oh-my-zsh with the `git` and `fzf` plugins,
powerlevel10k as the theme, `$EDITOR` pointed at neovim (with `vi`/`vim`/`v`
aliased to it, and `nvim +Man!` as the pager for man pages).

Two rules keep it portable: anything machine-specific is guarded
(`command -v go >/dev/null && export PATH=...`, so a box without Go still
opens a clean shell), and anything genuinely local — work paths, tokens,
one-off aliases — goes in **`~/.zshrc.local`**, which is sourced last and is
not in this repo. `$DOTFILES` points at the checkout, so `dots` cds here and
`dots-install` re-runs the installer.

**Vi mode.** `zsh/vi-mode.zsh` makes the command line itself modal: `Esc`
drops to normal mode and the usual motions and operators work on the prompt —
`ciw`, `di(`, `cs"'`, `yy`, `p`, `0`, `$`, `w`, `b`. Beyond `bindkey -v` it
adds the parts zsh leaves out:

| Key | Does |
| --- | --- |
| `Esc` | Leave insert mode (`KEYTIMEOUT=1`, so 10ms not 400ms) |
| cursor shape | Block in normal mode, bar in insert — via DECSCUSR |
| `ci"` `da(` `yi{` | Text objects (`select-bracketed` / `select-quoted`) |
| `cs"'` `ds(` `ys` | Surround (`cs` change, `ds` delete, `ys` add) |
| `k` / `j` in normal | History search on what you've already typed |
| `vv` in normal | Open the current line in `$EDITOR` |
| `y` in normal | Yank, and also copy to the macOS clipboard |
| `Ctrl+A` `Ctrl+E` `Ctrl+W` `Ctrl+R` | Kept from emacs mode, in insert mode |

The Esc delay is the whole reason `KEYTIMEOUT=1` is there — at the default
`40` (400ms) vi mode feels broken rather than fast. The tradeoff is that
multi-byte escape sequences typed by hand can be split; arrow keys are bound
explicitly in `viins` so they keep working regardless.

## Editors

Both editors use **Catppuccin Mocha with a transparent background**, which is
the point: Ghostty is running at 70% opacity over blurred application pixels,
and an editor that paints its own opaque background would punch a rectangle
through that effect.

**vim** (`vim/vimrc`). All four Catppuccin flavours are vendored into
`vim/colors/` — no plugin manager for vim, one `colorscheme` line to swap
(`catppuccin_mocha` | `macchiato` | `frappe` | `latte`; latte also wants
`set background=light`). `t_8f`/`t_8b` are set explicitly before
`termguicolors`, because `$TERM=xterm-ghostty` alone doesn't always get vim to
emit 24-bit colour. Then relative numbers, persistent undo in `~/.vim/undo`,
system clipboard, 4-space soft tabs.

**neovim** (`nvim/init.lua`). Single-file config, [lazy.nvim] bootstrapped by
the file itself, so a fresh machine needs no manual plugin step:

| Plugin | For |
| --- | --- |
| `catppuccin/nvim` | theme, `transparent_background = true` |
| `nvim-treesitter` | syntax (`main` branch API) |
| `telescope.nvim` | `<leader>f` files, `<leader>g` grep, `<leader>b` buffers |
| `neo-tree.nvim` | `<leader>e` file tree |
| `lualine` | statusline, catppuccin theme |
| `gitsigns` `autopairs` `Comment` `which-key` | the usual |

Leader is `Space`. Treesitter's `main` branch dropped `require("nvim-treesitter.configs")`,
so parsers are installed with `require("nvim-treesitter").install()` and
highlighting is switched on per buffer from a `FileType` autocmd — and it needs
the **`tree-sitter` CLI** on `PATH` to compile them (`brew install
tree-sitter-cli`, which `install.sh` does). `nvim/lazy-lock.json` is committed,
so every machine resolves the same plugin commits.

[lazy.nvim]: https://github.com/folke/lazy.nvim

## Install

```sh
git clone https://github.com/VQIVS/wezterm-hammerspoon.git
cd wezterm-hammerspoon
./install.sh
```

`install.sh` brings a fresh macOS machine all the way up, and is idempotent —
re-run it any time. It:

1. installs Homebrew if missing, then `git`, `neovim`, `tree-sitter-cli`,
   `fzf`, `ripgrep`, and the `ghostty`, `wezterm`, `hammerspoon` casks;
2. installs oh-my-zsh (with `KEEP_ZSHRC=yes`, so it won't clobber ours) and
   powerlevel10k;
3. symlinks every config in the map above, moving anything already there to
   `*.bak`;
4. bootstraps neovim — `Lazy! sync` for plugins, then compiles the treesitter
   parsers;
5. copies [MesloLGS Nerd Font] from `fonts/` into `~/Library/Fonts/` (copied,
   not linked: macOS font registration doesn't reliably follow symlinks out of
   that folder), and seeds a Ghostty backdrop.

```sh
./install.sh --no-deps    # configs only, no brew / oh-my-zsh installs
```

Three things it can't do for you: grant Accessibility permission in System
Settings → Privacy & Security to **Hammerspoon** (for `Ctrl+Escape`) and
**Ghostty** (for `Ctrl+T`), `chsh -s $(which zsh)` if zsh isn't your login
shell, and `p10k configure` if you want a prompt other than the committed
`~/.p10k.zsh`.

[MesloLGS Nerd Font]: https://github.com/ryanoasis/nerd-fonts/releases/latest
