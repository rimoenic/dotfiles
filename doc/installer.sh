#!/bin/bash

DOTPATH=$HOME/.dotfiles

if [ ! -z "$WSLENV" ]; then
    local TARGET_ENV=wsl
else
    local TARGET_ENV=other
fi



case $TARGET_ENV in
    wsl)
        USERPROFILE_PATH=$(wslpath $(wslvar USERPROFILE))
        DOTPATH_REAL=${USERPROFILE_PATH}/.dotfiles
        if [ ! -L ${DOTPATH} ]; then
            mv ${DOTPATH} ${DOTPATH}.orig || exit 1
            ln -snfv ${DOTPATH_REAL} ${DOTPATH}
        fi
        ;;
    *)
        DOTPATH_REAL=${DOTPATH}
        ;;
esac



if [[ ! -f  ${DOTPATH_REAL}/doc/installer.sh ]]; then
    mv ${DOTPATH_REAL} ${DOTPATH_REAL}.orig || exit 1
    git clone https://github.com/rimoenic/dotfiles $DOTPATH_REAL

fi



TARGETS=(
    .zshrc
    .dircolors
    .tmux.conf
)

for val in ${TARGETS[@]};
do
    SOURCE=$(readlink -f "${DOTPATH}/${val}")
    ln -snfv "${SOURCE}" "$HOME/${val}"
done

