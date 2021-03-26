#!/bin/bash

DOTPATH=$HOME/.dotfiles

if [[ ! -f  ${DOTPATH}/doc/installer.sh ]]; then
    mv ${DOTPATH} ${DOTPATH}.orig
    git clone https://github.com/rimoenic/dotfiles $DOTPATH
fi



TARGETS=(
    .zshrc
    .dircolors
)

for val in ${TARGETS[@]};
do
    SOURCE=$(readlink -f "${DOTPATH}/${val}")
    ln -snfv "${SOURCE}" "$HOME/${val}"
done

