#!/bin/bash

DOTPATH=$HOME/.dotfiles

if [ ! -z "$WSLENV" ]; then
    TARGET_ENV=wsl
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

        # copy C:\Users\<USER_NAME>\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json C:\Users\<USER_NAME>\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json.bak
        # rmdir C:\Users\<USER_NAME>\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
        # mklink /H C:\Users\<USER_NAME>\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json settings.json
        WT_SETTINGS_JSON=${USERPROFILE_PATH}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json
        [[ ! -e ${WT_SETTINGS_JSON} ]] && { echo Reinstall this after install windows terminal from microsoft store; exit 1; }
        NUM_LINKS=$(stat ${WT_SETTINGS_JSON} | head -n 3 | tail -n 1 | sed -r 's@.*\s*Links:\s*([0-9]+)@\1@')
        if [[ ${NUM_LINKS} -eq 1 ]]; then
            cp "${WT_SETTINGS_JSON}" "${WT_SETTINGS_JSON}.bak"
            rm "${WT_SETTINGS_JSON}"
            ln -nfv "${DOTPATH_REAL}/windows/WindowsTerminal/settings.json" "${WT_SETTINGS_JSON}"
        fi
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




