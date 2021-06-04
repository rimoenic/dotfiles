
DOTFILESPATH=$HOME/.dotfiles/


_load_settings() {
    _dir="$1"
    if [ ! -d "$_dir" ]; then
       return 1
    fi

    for config in "$_dir"/**/*(N-.); do
        case "$config" in
            *.zwc)
                :
                ;;
            *)
                . $config
                ;;
        esac
    done
}
_load_settings "${DOTFILESPATH}/zsh"



#----- direnv
if [ -e "$(which direnv)" ]; then
    eval "$(direnv hook zsh)"
else
    cat <<_EOF
direnv is not installed. Don't you need?
$ sudo apt install direnv
_EOF
fi

export PATH="$HOME/.local/bin:$PATH"

#----- anyenv
if [ -d "$HOME/.anyenv/bin" ]; then
    export PATH="$HOME/.anyenv/bin:$PATH"
    eval "$(anyenv init -)"
else
    git clone https://github.com/anyenv/anyenv ~/.anyenv
    export PATH="$HOME/.anyenv/bin:$PATH"
    anyenv install --force-init
    anyenv install pyenv
    exec $SHELL -l
fi

#----- asdf
if [ -d "$HOME/.asdf" ]; then
    source $HOME/.asdf/asdf.sh
#    fpath=(${ASDF_DIR}/completions $fpath)
#    # initialise completions with ZSH's compinit
#    autoload -Uz compinit
#    compinit
else
    # https://asdf-vm.com/#/core-manage-asdf
    git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.8.1
    cat <<_EOF
asdf plugin is empty now. Don't you need some plugins(python, etc...)?
$ asdf plugin add python
_EOF
fi
    
# git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
# ~/.fzf/install
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

#function ghq-fzf() {
#  local src=$(ghq list | fzf --preview "ls -lap -T8 $(ghq root)/{} | tail -n+4 | awk '{print \$9\"/\"\$6\"/\"\$7 \" \" \$10}'")
#  if [ -n "$src" ]; then
#    BUFFER="cd $(ghq root)/$src"
#    zle accept-line
#  fi
#  zle -R -c
#}
function ghq-fzf() {
  local selected_dir=$(ghq list | fzf-tmux --query="$LBUFFER")

  if [ -n "$selected_dir" ]; then
    BUFFER="cd $(ghq root)/${selected_dir}"
    zle accept-line
  fi

  zle reset-prompt
}
zle -N ghq-fzf
bindkey '^]' ghq-fzf


function ssh-fzf () {
  local selected_host=$(grep "Host " ~/.ssh/config | grep -v '\*' | cut -b 6- | sed -r 's/ /\n/' | sort | uniq | fzf-tmux --query "$LBUFFER")

  if [ -n "$selected_host" ]; then
    BUFFER="ssh ${selected_host}"
    zle accept-line
  fi
  zle reset-prompt
}
zle -N ssh-fzf
bindkey '^\' ssh-fzf


#PATH重複排除 末尾で実行
typeset -U path

