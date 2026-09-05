# Fonts

`MesloLGS Nerd Font Mono` — the family `wezterm/wezterm.lua` asks for as its
primary font. Version 3.5.1, from the [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)
Meslo release. Only the four styles WezTerm actually resolves are vendored
here (regular, bold, italic, bold-italic); the LGL/LGM/DZ line-gap and
zero-style variants are not used.

Meslo LG is licensed Apache 2.0; the Nerd Fonts patching adds glyphs under
the same terms.

`install.sh` copies these into `~/Library/Fonts/`. macOS picks them up without
a restart, though WezTerm needs to be relaunched to notice a first-time install.

The config's second fallback, `Symbols Nerd Font Mono`, ships inside WezTerm
itself and needs no installation.
