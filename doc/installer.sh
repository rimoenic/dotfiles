#!/bin/bash

set -eu

DOTPATH=$HOME/.dotfiles

if [ ! -z "$WSLENV" ]; then
    TARGET_ENV=wsl

    if ! which wslvar; then
        case "$(grep '^ID=' /etc/os-release | sed 's/^ID=\(.*\)$/\1/')" in
            ubuntu)
                sudo apt -y update && sudo apt -y upgrade
                if grep '^VERSION_ID=' /etc/os-release | grep -E '2[24].04'; then
                    sudo apt -y install wslu
                fi
                ;;
            *)
            ;;
        esac
    fi
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

function install_nix()
{
    if ! which nix; then
        curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install
        # インストーラー実行後、現在のシェルセッションにnixを読み込む
        if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
            . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
        fi
    fi
}

function apply_home_manager()
{
    nix run github:nix-community/home-manager -- switch --flake "${DOTPATH}/nix#default" --impure
}


case $TARGET_ENV in
    wsl)
        DOTPATH_REAL=${USERPROFILE_PATH}/.dotfiles
        clone_repo "${DOTPATH_REAL}"

        if [ ! -L ${DOTPATH} ]; then
            if [[ -d ${DOTPATH} ]]; then
                mv ${DOTPATH} ${DOTPATH}.orig || exit 1
            fi
            ln -snfv ${DOTPATH_REAL} ${DOTPATH}
        fi

        # NOTE: overwrites existing /etc/wsl.conf
        if [ -f /etc/wsl.conf ]; then
            if [ ! -f /etc/wsl.conf.orig ]; then
                sudo cp /etc/wsl.conf /etc/wsl.conf.orig
            else
                echo "Current /etc/wsl.conf (will be overwritten):"
                cat /etc/wsl.conf
            fi
        fi
        sudo tee /etc/wsl.conf > /dev/null << EOF
[boot]
systemd = true

[automount]
enable = true
root = /mnt/
options = "metadata,uid=$(id -u),gid=$(id -g),umask=22,fmask=11"

[user]
default = ${USER}
EOF

        echo " "
        echo "###########################"
        echo " Run setup.ps1 on Windows to configure Windows Terminal, oh-my-posh and .wslconfig:"
        echo " "
        echo " > powershell -ExecutionPolicy Bypass -File $(wslpath -w ${DOTPATH_REAL}/windows/setup.ps1)"
        echo "###########################"
        echo " "
        ;;
    *)
        DOTPATH_REAL=${DOTPATH}
        clone_repo "${DOTPATH_REAL}"
        ;;
esac

install_nix
apply_home_manager

if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
    if which locale-gen &>/dev/null; then
        sudo locale-gen en_US.UTF-8
        sudo localectl set-locale LANG=en_US.UTF-8
    else
        echo "Warning: locale-gen not found. Please install 'locales' package and configure en_US.UTF-8 manually:"
        echo "# sudo locale-gen en_US.UTF-8"
        echo "# sudo localectl set-locale LANG=en_US.UTF-8"
    fi
fi


TARGETS=(
    .zshrc
    .dircolors
    .ackrc
)

for val in ${TARGETS[@]};
do
    SOURCE=$(readlink -f "${DOTPATH}/${val}")
    ln -snfv "${SOURCE}" "$HOME/${val}"
done


[ ! -e "$HOME/.config/nvim" ] && mkdir "$HOME/.config/nvim"
[ ! -e "$HOME/.config/nvim/init.vim" ] && ln -snfv $(readlink -f "${DOTPATH}/nvim/init.vim") "$HOME/.config/nvim/init.vim"

