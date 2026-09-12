#!/usr/bin/env bash
# Reproduce this terminal setup on a fresh macOS machine:
# Ghostty + WezTerm + Hammerspoon, zsh (oh-my-zsh + powerlevel10k, vi mode),
# vim and neovim themed to match. Idempotent -- safe to re-run.
#
#   ./install.sh            # everything
#   ./install.sh --no-deps  # configs only, skip brew/oh-my-zsh installs
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
with_deps=1
[ "${1:-}" = "--no-deps" ] && with_deps=0

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }

link() {
   local src="$1" dest="$2"
   mkdir -p "$(dirname "$dest")"
   if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      mv "$dest" "$dest.bak"
      info "backed up $dest -> $dest.bak"
   fi
   ln -sfn "$src" "$dest"
   info "linked $(basename "$dest")"
}

# ─── dependencies ────────────────────────────────────────────────────────────
if [ "$with_deps" = 1 ]; then
   say "Dependencies"

   if ! command -v brew >/dev/null; then
      info "installing Homebrew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # make brew usable in this script run (Apple Silicon and Intel paths)
      for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
         [ -x "$b" ] && eval "$("$b" shellenv)"
      done
   fi

   # neovim needs a real git + the tree-sitter CLI to build parsers
   for f in git neovim tree-sitter-cli fzf ripgrep; do
      if brew list --formula "$f" >/dev/null 2>&1; then
         info "$f already installed"
      else
         info "brew install $f"
         brew install "$f"
      fi
   done

   for c in "ghostty:Ghostty" "wezterm:WezTerm" "hammerspoon:Hammerspoon"; do
      cask="${c%%:*}"; app="${c##*:}"
      if [ -d "/Applications/$app.app" ] || brew list --cask "$cask" >/dev/null 2>&1; then
         info "$cask already installed"
      else
         info "brew install --cask $cask"
         brew install --cask "$cask" || info "could not install $cask -- install it by hand"
      fi
   done

   # oh-my-zsh + powerlevel10k (the theme ~/.zshrc asks for)
   export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
   if [ ! -d "$ZSH" ]; then
      info "installing oh-my-zsh"
      RUNZSH=no KEEP_ZSHRC=yes \
         sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   else
      info "oh-my-zsh already installed"
   fi

   p10k="${ZSH_CUSTOM:-$ZSH/custom}/themes/powerlevel10k"
   if [ ! -d "$p10k" ]; then
      info "installing powerlevel10k"
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k"
   else
      info "powerlevel10k already installed"
   fi
fi

# ─── terminal / window manager configs ───────────────────────────────────────
say "Terminal configs"
link "$repo/wezterm/wezterm.lua"   "$HOME/.config/wezterm/wezterm.lua"
link "$repo/hammerspoon/init.lua"  "$HOME/.hammerspoon/init.lua"
link "$repo/ghostty/config"        "$HOME/.config/ghostty/config"
link "$repo/ghostty/backdrop.sh"   "$HOME/.config/ghostty/backdrop.sh"

# ─── shell ───────────────────────────────────────────────────────────────────
say "Shell (zsh)"
# zsh/vi-mode.zsh is sourced straight out of the repo by zsh/zshrc, so only the
# entry point needs a link.
link "$repo/zsh/zshrc"    "$HOME/.zshrc"
link "$repo/zsh/p10k.zsh" "$HOME/.p10k.zsh"
if [ "$SHELL" != "$(command -v zsh)" ]; then
   info "default shell is $SHELL; switch with: chsh -s $(command -v zsh)"
fi

# ─── editors ─────────────────────────────────────────────────────────────────
say "Editors (vim + neovim)"
link "$repo/vim/vimrc" "$HOME/.vimrc"
mkdir -p "$HOME/.vim/colors" "$HOME/.vim/undo"
for scheme in "$repo"/vim/colors/*.vim; do
   link "$scheme" "$HOME/.vim/colors/$(basename "$scheme")"
done
link "$repo/nvim/init.lua" "$HOME/.config/nvim/init.lua"
# lazy.nvim writes its lockfile next to init.lua; keeping it in the repo pins
# the same plugin commits on every machine.
touch "$repo/nvim/lazy-lock.json"
link "$repo/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"

if command -v nvim >/dev/null; then
   info "bootstrapping neovim plugins (lazy.nvim clones on first run)"
   nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true
   if command -v tree-sitter >/dev/null; then
      info "building treesitter parsers"
      nvim --headless -c 'lua
         local langs = {"lua","vim","vimdoc","bash","go","python","json","yaml","markdown","markdown_inline"}
         require("nvim-treesitter").install(langs)
         -- wait (up to 5 min) until every parser is on disk, then quit
         vim.wait(300000, function()
            for _, l in ipairs(langs) do
               if #vim.api.nvim_get_runtime_file("parser/" .. l .. ".so", false) == 0 then return false end
            end
            return true
         end, 500)' -c 'qa!' >/dev/null 2>&1 || true
   else
      info "tree-sitter CLI missing -- parsers will not build (brew install tree-sitter-cli)"
   fi
fi

# ─── fonts ───────────────────────────────────────────────────────────────────
say "Fonts"
# Copied rather than symlinked -- macOS font registration does not reliably
# follow links out of ~/Library/Fonts.
fonts="$HOME/Library/Fonts"
mkdir -p "$fonts"
for font in "$repo"/fonts/*.ttf; do
   cp -f "$font" "$fonts/"
   info "installed $(basename "$font")"
done

# ─── backdrops ───────────────────────────────────────────────────────────────
say "Backdrops"
mkdir -p "$HOME/.config/wezterm/backdrops"
# Ghostty has no scripting hook, so its backdrop is a generated include file;
# seed one now. Harmless failure on a machine with no wallpapers yet -- the
# include is optional (`?backdrop.conf`).
"$repo/ghostty/backdrop.sh" random >/dev/null 2>&1 || info "no backdrops yet -- skipped"

# ─── done ────────────────────────────────────────────────────────────────────
cat <<'DONE'

──────────────────────────────────────────────────────────────────────────────
Done. Remaining manual steps:

  1. Grant Accessibility permission in System Settings -> Privacy & Security
     to Hammerspoon (Ctrl+Escape -> WezTerm) and Ghostty (Ctrl+T -> quick
     terminal). Global hotkeys do not work without it.
  2. `exec zsh` (or open a new terminal) to pick up the shell config.
  3. `p10k configure` if you want a different prompt than the committed one.
  4. Drop wallpapers into ~/.config/wezterm/backdrops/ and list them in the
     BACKDROPS table in wezterm/wezterm.lua and ghostty/backdrop.sh.

Machine-specific shell bits (work paths, tokens, one-off aliases) go in
~/.zshrc.local -- it is sourced last and never committed.
──────────────────────────────────────────────────────────────────────────────
DONE
