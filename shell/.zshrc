
# --- History Configuration ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY          # Share history between active terminal tabs
setopt HIST_IGNORE_ALL_DUPS   # Eliminate duplicate entries
setopt HIST_REDUCE_BLANKS     # Remove unnecessary blanks

# --- Basic Completion ---
autoload -Uz compinit
compinit

# Enable fzf-tab
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh

# Style the fzf popup to match Catppuccin Mocha colors
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"

# Preview directory contents with eza when tabbing through 'cd'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'

# Switch group presentation
zstyle ':fzf-tab:*' switch-group '<' '>'


# --- Eza Aliases ---
alias ls='eza --tree --level=1 --icons=auto --group-directories-first'
alias l='eza -l --icons=auto --group-directories-first'
alias ll='eza -lh --icons=auto --git --group-directories-first'
alias la='eza -a --icons=auto --group-directories-first'
alias lla='eza -lha --icons=auto --git --group-directories-first'
alias lt='eza --tree --level=2 --icons=auto'
alias lta='eza --tree --level=2 -a --icons=auto'

# --- Useful Everyday Aliases ---
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias mkdir='mkdir -p'

# --- Prompt (Optional: Starship) ---
# If using starship prompt:
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi


#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Initialize Starship
eval "$(starship init zsh)"

# Save prompt state and restore it before each new active line
STARSHIP_PROMPT="$PROMPT"
_restore_prompt() {
  PROMPT="$STARSHIP_PROMPT"
  echo -ne '\e[6 q'
}
precmd_functions+=(_restore_prompt)

# Transient prompt: collapses to ONLY the blue arrow without '╰─' once executed
autoload -Uz add-zle-hook-widget
_transient_prompt() {
  PROMPT="%B%F{#89b4fa}❯%f%b "
  zle reset-prompt
}
add-zle-hook-widget zle-line-finish _transient_prompt
