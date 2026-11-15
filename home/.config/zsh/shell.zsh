# Shell extras: history, fzf, zoxide, plugins, aliases
export PATH="$HOME/.local/bin:$PATH"
HISTSIZE=100000
SAVEHIST=100000
unsetopt CORRECT
setopt HIST_IGNORE_SPACE HIST_IGNORE_ALL_DUPS AUTO_CD
zstyle ':completion:*' list-colors "di=38;2;223;197;142"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%B%d%b%f'
export FZF_DEFAULT_OPTS='--height=45% --layout=reverse --border=sharp --color=bg:#242427,bg+:#514b3d,fg:#cecec8,hl:#dfc58e,pointer:#dfc58e,info:#91918b,prompt:#dfc58e'
[[ -o zle ]] && (( $+commands[fzf] )) && source <(fzf --zsh)
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
for plugin in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
 [[ -f $plugin ]] && source "$plugin"
done
alias top='btop'
alias tree='eza --tree --level=2 --icons'
alias preview='fzf --preview "bat --color=always --style=numbers --line-range=:200 {}"'
alias mkcd='mkdircd'
mkdircd() { mkdir -p -- "$1" && cd -- "$1"; }
(( $+commands[starship] )) && eval "$(starship init zsh)"

# Muted suggestions and syntax colors match the wallpaper deck.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#77776f'
if (( $+parameters[ZSH_HIGHLIGHT_STYLES] )); then
    ZSH_HIGHLIGHT_STYLES[command]='fg=#dfc58e'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=#dfc58e'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=#dfc58e'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#e1ac96'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#a7b18a'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#a7b18a'
    ZSH_HIGHLIGHT_STYLES[path]='fg=#cecec8,underline'
fi
