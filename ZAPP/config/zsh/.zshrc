#====================
# Random Vars
#====================
export BAT_THEME='base16'
#====================
# Plugins
#====================
plugin_dir="/usr/share/zsh/plugins"
source $plugin_dir/zsh-vi-mode/zsh-vi-mode.plugin.zsh 
source $plugin_dir/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
source $plugin_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
#====================
# Plugin config
#====================
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLOCK
#====================
# Aliases
#====================
alias ls="ls -AhXl --color"
alias lls="ls -AhlS --color"
alias du="du --max-depth=1 -h | sort -hr" 
alias pp="sudo pacman -Sy --noconfirm"
alias ppp="sudo pacman -Suy --noconfirm"
alias yy="yay -Sy --noconfirm"
alias yyy="yay -Suy --noconfirm"
# extra tools
alias jd="flatpak info org.jdownloader.JDownloader > /dev/null 2>&1 && \
    { _JAVA_AWT_WM_NONREPARENTING=1 GDK_BACKEND=x11 \
    setsid flatpak run org.jdownloader.JDownloader > /dev/null 2>&1 \
    < /dev/null ; exit ; }"
alias rmpc="rmpc -c ${ZAPP_PATH}/config/rmpc/config.ron"
#====================
# Force Vim bindings
#====================
bindkey -v
#====================
# Colored Man Pages
#====================
export PAGER=less
export GROFF_NO_SGR=1
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'
#====================
# Tab Complition Highlights
#====================
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
#====================
# Command History 
#====================
HISTFILE="${ZDOTDIR}/.zsh_history"
HISTSIZE=5000
SAVEHIST=5000
setopt APPEND_HISTORY       # Append to history instead of overwriting
setopt INC_APPEND_HISTORY   # Save every command immediately
setopt SHARE_HISTORY        # Share history across sessions
#====================
# Helpers
#====================
#yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}
#fzf
source <(fzf --zsh)
export FZF_DEFAULT_COMMAND='fd --hidden --strip-cwd-prefix --exclude .git'
export FZF_DEFAULT_OPTS="\
--height 100% \
--layout default \
--preview-label=[preview] \
--list-label=[list] \
--preview-window=up,wrap \
--style=full:bold \
--color=base16,border:4,gutter:0,bg+:4,fg+:0,hl+:0"
export FZF_ALT_C_COMMAND='fd --type=d --hidden --strip-cwd-prefix --exclude .git'
export FZF_CTRL_T_OPTS='--preview "\
    if [[ -d {} ]] ; then \
        ls -AhXl --color {} ; \
    elif [[ -f {} ]] ; \
        then bat -p --color=always {} ; \
    fi"'
export FZF_ALT_C_OPTS='--preview "tree -C {}"'
#====================
# Prompt
#====================
setopt PROMPT_SUBST
function gen_prompt() {
    local PWD="$(pwd)"
    if [[ "$PWD" == "$HOME" ]] ; then 
        local PROMPT_PATH="${PWD/$HOME/}"
        local PROMPT_PATH_COMPONEMT='~'
    elif [[ "$PWD" =~ "$HOME" ]] ; then
        local PROMPT_PATH_COMPONEMT='~/'
        local PROMPT_PATH="${PWD/$HOME/}"
    else
        local PROMPT_PATH_COMPONEMT='/'
        local PROMPT_PATH="${PWD}"
    fi
    IFS=/ read -rA PATH_COMPONENTS <<< "${PROMPT_PATH#/}"
    PATH_COMPONENTS_LEN="${#PATH_COMPONENTS[@]}"

    local i=1
    while true; do 
        # remove the extra '/' at the end  and break
        [[ "$i" -gt "$PATH_COMPONENTS_LEN" ]] && \
            { PROMPT_PATH_COMPONEMT="${PROMPT_PATH_COMPONEMT%/}" ; break ; }

        if [[ "$i" -le $(( "$PATH_COMPONENTS_LEN" - 2 )) ]] ; then
            PROMPT_PATH_COMPONEMT+="${PATH_COMPONENTS[i]:0:1}/"
        else 
            # Shrink if the directory name is bigger then 40% of the 
            # width of the terminal 
            if (( ${#PATH_COMPONENTS[i]} > ( COLUMNS * 40 / 100 ) )) ; then
                PROMPT_PATH_COMPONEMT+="${PATH_COMPONENTS[i]:0:5}../"
            else 
                PROMPT_PATH_COMPONEMT+="${PATH_COMPONENTS[i]}/"
            fi
        fi
        (( i++ ))
    done
    PROMPT_COMP1="┌%K{4} %F{0}%B%n%b%f %k"
    PROMPT_COMP2="%K{4}%F{8}%f%k%K{0}%F{8}%f%k"
    PROMPT_COMP3=" $PROMPT_PATH_COMPONEMT"
    PROMPT_COMP4="%F{8} %f"
    PROMPT_COMP5="└─(%(?.%F{5}%(!.#.$)%f.%F{1}%(!.#.$))%f) "
    
    # Notice the single quotes, set the value as a literal string
    # zsh does the updating by itself, if double quotes are used
    # zsh will parse one time and foget..:)
    PROMPT="$PROMPT_COMP1$PROMPT_COMP2$PROMPT_COMP3$PROMPT_COMP4
$PROMPT_COMP5"
}
misc(){
    # fix Ctrl-R not working with zsh-vi-mode plugin
    bindkey '^R' fzf-history-widget
}
precmd_functions+=(gen_prompt misc)
