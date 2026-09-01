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

mkdir -p "$HOME/.config/wezterm/backdrops"
echo
echo "Drop wallpapers into ~/.config/wezterm/backdrops/ and list them in"
echo "the BACKDROPS table in wezterm/wezterm.lua."
