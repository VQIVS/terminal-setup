#!/usr/bin/env bash
# Symlink the configs into place, backing up whatever is already there.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
   local src="$1" dest="$2"
   mkdir -p "$(dirname "$dest")"
   if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      mv "$dest" "$dest.bak"
      echo "backed up $dest -> $dest.bak"
   fi
   ln -sfn "$src" "$dest"
   echo "linked $dest"
}

link "$repo/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
link "$repo/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"
link "$repo/ghostty/config" "$HOME/.config/ghostty/config"
link "$repo/ghostty/backdrop.sh" "$HOME/.config/ghostty/backdrop.sh"

# Fonts are copied rather than symlinked -- macOS font registration does not
# reliably follow links out of ~/Library/Fonts.
fonts="$HOME/Library/Fonts"
mkdir -p "$fonts"
for font in "$repo"/fonts/*.ttf; do
   cp -f "$font" "$fonts/"
   echo "installed font $(basename "$font")"
done

mkdir -p "$HOME/.config/wezterm/backdrops"

# Ghostty has no scripting hook, so its backdrop is a generated include file;
# seed one now. Harmless failure on a machine with no wallpapers yet -- the
# include is optional (`?backdrop.conf`).
"$repo/ghostty/backdrop.sh" random || true

echo
echo "Drop wallpapers into ~/.config/wezterm/backdrops/ and list them in the"
echo "BACKDROPS table in wezterm/wezterm.lua and ghostty/backdrop.sh (shared"
echo "folder, one list each)."
echo
echo "Then grant Accessibility permission in System Settings -> Privacy &"
echo "Security to Hammerspoon (Ctrl+Escape -> WezTerm) and to Ghostty"
echo "(Ctrl+T -> quick terminal)."
