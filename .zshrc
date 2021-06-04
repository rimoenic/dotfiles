
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

#PATH重複排除 末尾で実行
typeset -U path

