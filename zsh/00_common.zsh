# -*- shell-script -*-
autoload colors
local p_cdir="%B[%F{blue}%~%f]%b"
local p_info="%F{magenta}%n@%m%f"
local p_mark="%B%(?,%F{green},%F{red})%(!,#,$)%f%b"
PROMPT="$p_info$p_mark "
RPROMPT="$p_cdir"

if [ $USER = "root" ]
    then
    #PROMPT=$'%{\e[01;31m%}%m%{\e[m%}> '
    else
    #PROMPT=$'%{\e[35m%}%n@%m%{\e[m%}$ '
fi
#RPROMPT=$'[%{\e[34m%}%~%{\e[m%}]'

HISTFILE=$HOME/.zsh_history # 履歴をファイルに保存する
HISTSIZE=100000             # メモリ内の履歴の数
SAVEHIST=100000             # 保存される履歴の数
setopt extended_history     # 履歴ファイルに時刻を記録
setopt share_history        # 履歴ファイルを逐次保存
setopt extended_glob
setopt pushd_ignore_dups
setopt auto_cd
setopt auto_pushd
setopt no_hup
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt always_last_prompt
setopt pushd_silent
setopt print_eight_bit
setopt no_list_beep
setopt no_list_types
setopt no_flow_control
setopt ignore_eof

precmd() {
    case $TERM in
        (screen|[kx]term*))
        print -nP "\e]2;%/\a"
        ;;
    esac
}

preexec() {
    case $TERM in
        (screen|[kx]term*))
        emulate -L zsh
        local -a cmd; cmd=(${(z)1})		# Re-parse the command line
        print -n "\e]2;$cmd[1]\a"
        ;;
    esac
}

bindkey -e


zstyle :compinstall filename "${HOME}/.zshrc"

autoload -Uz compinit
compinit -u

zstyle ':completion:*:default' menu select=1
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'



