#!/bin/bash

set -eu

DOTPATH=$HOME/.dotfiles

if [ ! -z "$WSLENV" ]; then
    TARGET_ENV=wsl

    case "$(grep '^ID=' /etc/os-release | sed 's/^ID=(.*)$/\1/')" in
        ubuntu)
            sudo apt update && sudo apt upgrade
            if grep '^VERSION_ID=' /etc/os-release | grep '22.04'; then
                 sudo apt install wslu
            fi
            ;;
        *)
         ;;
    esac
    USERPROFILE_PATH=$(wslpath $(wslvar USERPROFILE))
else
    TARGET_ENV=other
fi

function clone_repo()
{
    local DEPLOY_PATH=$1

    [[ $# -lt 1 ]] && { echo usage: clone_repo DEPLOY_PATH; exit 1;}
    [[ -d ${DEPLOY_PATH} ]] || { echo ${DEPLOY_PATH} is not Dir; exit 1; }

    if [[ ! -f  ${DEPLOY_PATH}/doc/installer.sh ]]; then
        mv "${DEPLOY_PATH}" "${DEPLOY_PATH}.orig" || { echo directory backup failed; exit 1; }
        git clone https://github.com/rimoenic/dotfiles "${DEPLOY_PATH}"
    fi
}

case $TARGET_ENV in
    wsl)
        DOTPATH_REAL=${USERPROFILE_PATH}/.dotfiles
        clone_repo "${DOTPATH_REAL}"

        if [ ! -L ${DOTPATH} ]; then
            mv ${DOTPATH} ${DOTPATH}.orig || exit 1
            ln -snfv ${DOTPATH_REAL} ${DOTPATH}
        fi

        WT_SETTINGS_DIR=${USERPROFILE_PATH}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/
        [[ ! -e ${WT_SETTINGS_DIR} ]] && { echo Reinstall this after install windows terminal from microsoft store; exit 1; }

        echo "###########################"
        echo " Need to copy the settings.json to ${WT_SETTINGS_DIR} manually."
        echo "###########################"
        echo copy "${DOTPATH_REAL}/windows/WindowsTerminal/settings.json" "${WT_SETTINGS_DIR}"
        ;;
    *)
        DOTPATH_REAL=${DOTPATH}
        clone_repo "${DOTPATH_REAL}"
        ;;
esac






TARGETS=(
    .zshrc
    .dircolors
    .tmux.conf
    .ackrc
)

for val in ${TARGETS[@]};
do
    SOURCE=$(readlink -f "${DOTPATH}/${val}")
    ln -snfv "${SOURCE}" "$HOME/${val}"
done


[ ! -e "$HOME/.config/nvim" ] && mkdir "$HOME/.config/nvim"
[ ! -e "$HOME/.config/nvim/init.vim" ] && ln -snfv $(readlink -f "${DOTPATH}/nvim/init.vim") "$HOME/.config/nvim/init.vim"

