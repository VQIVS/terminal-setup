# ─── zsh vi mode ─────────────────────────────────────────────────────────────
# Modal editing on the command line itself: Esc leaves insert mode, then the
# usual motions/operators (w b e 0 $ ci" di( yy p ...) work on the prompt.

bindkey -v
export KEYTIMEOUT=1          # 10ms Esc delay instead of the 0.4s default

# ─── cursor shape follows the mode ───────────────────────────────────────────
# Beam in insert, block in normal -- so you can always see which mode you're
# in. Ghostty/WezTerm both honour DECSCUSR.
_vi_cursor() {
   case ${KEYMAP:-viins} in
      vicmd)            printf '\e[2 q' ;;   # steady block
      viins|main|*)     printf '\e[6 q' ;;   # steady bar
   esac
}
zle -N zle-keymap-select _vi_cursor
zle -N zle-line-init     _vi_cursor
precmd_functions+=(_vi_cursor_reset)
_vi_cursor_reset() { printf '\e[6 q' }       # never leave a block behind

# ─── insert-mode keys worth keeping ──────────────────────────────────────────
bindkey -M viins '^?' backward-delete-char   # backspace past the insert point
bindkey -M viins '^h' backward-delete-char
bindkey -M viins '^w' backward-kill-word
bindkey -M viins '^u' backward-kill-line
bindkey -M viins '^a' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins '^k' kill-line
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M viins '^p' up-line-or-history
bindkey -M viins '^n' down-line-or-history
bindkey -M viins '^l' clear-screen

# ─── history search on the current prefix ────────────────────────────────────
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey -M viins '^[[A' up-line-or-beginning-search     # Up
bindkey -M viins '^[[B' down-line-or-beginning-search   # Down
bindkey -M vicmd 'k'    up-line-or-beginning-search
bindkey -M vicmd 'j'    down-line-or-beginning-search
bindkey -M vicmd '/'    history-incremental-search-backward
bindkey -M vicmd '?'    history-incremental-search-forward

# ─── text objects: ci" di( ya{ etc. ──────────────────────────────────────────
autoload -Uz select-bracketed select-quoted
zle -N select-bracketed
zle -N select-quoted
for m in viopp visual; do
   for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do bindkey -M $m "$c" select-bracketed; done
   for c in {a,i}${(s..)^:-\'\"\`}; do bindkey -M $m "$c" select-quoted; done
done

# ─── surround: cs"' ds" ys ───────────────────────────────────────────────────
autoload -Uz surround
zle -N delete-surround surround
zle -N add-surround     surround
zle -N change-surround  surround
bindkey -M vicmd  cs change-surround
bindkey -M vicmd  ds delete-surround
bindkey -M vicmd  ys add-surround
bindkey -M visual S  add-surround

# ─── v in normal mode opens the line in $EDITOR ──────────────────────────────
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'vv' edit-command-line

# ─── yank to the macOS clipboard ─────────────────────────────────────────────
_vi_yank_pbcopy() { zle vi-yank; printf '%s' "$CUTBUFFER" | pbcopy }
zle -N _vi_yank_pbcopy
bindkey -M vicmd 'y' _vi_yank_pbcopy

# p10k shows the mode in the prompt via its `vi_mode` segment; if you don't see
# it, run `p10k configure` or add vi_mode to POWERLEVEL9K_*_PROMPT_ELEMENTS.
typeset -g POWERLEVEL9K_VI_INSERT_MODE_STRING=''
typeset -g POWERLEVEL9K_VI_COMMAND_MODE_STRING='NORMAL'
