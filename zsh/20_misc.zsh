

SSH_AGENT_FILE="$HOME/.ssh/.ssh-agent-info"
function start_ssh_agent()
{
        ssh-agent >${SSH_AGENT_FILE}
        chmod 600 ${SSH_AGENT_FILE}
        source ${SSH_AGENT_FILE} >/dev/null
        FIRSTZSHPID=$$
        export FIRSTZSHPID
        #ssh-add
}
function ssh_agent_is_available()
{
        [ -f ${SSH_AGENT_FILE} ] || return 1

        source ${SSH_AGENT_FILE} >/dev/null
        ps -p ${SSH_AGENT_PID:-999999} | grep -q 'ssh-agent$' || return 1
        test -S $SSH_AUTH_SOCK || return 1

        return 0
}
function clean_all_ssh_agent()
{
        for p in $(pgrep ssh-agent); do
                SSH_AGENT_PID=$p
                ssh-agent -k
        done
        find /tmp -type d -iname "ssh-*" -print0 | xargs -0 rm -rf
}

if ! ssh_agent_is_available; then
        clean_all_ssh_agent
        start_ssh_agent
fi


 
# copy to clipboard for cygwin
alias -g CLIP="| clip.exe" 

export GOPATH="$HOME/.go"
export PATH="$HOME/bin:${PATH}"
export PATH="$GOPATH/bin:${PATH}:/usr/local/go/bin:"

export LANG=en_US.UTF-8
export EDITOR=vi


# #export LESS='-j10 --no-init --quit-if-one-screen --RAW-CONTROL-CHARS'
# export LESS='-j10 --no-init --quit-if-one-screen'
# #export LESSOPEN='| /usr/bin/src-hilite-lesspipe.sh <(~/bin/lesspipe.sh %s)'
# export LESSOPEN='| ~/bin/lesspipe.sh %s'

export DISPLAY=:0
#XWin -clipboard -multiwindow -silent-dup-error > /dev/null 2>&1 &
#TRAPEXIT() {
#	kill %$(jobs | grep XWin | sed 's@\[\([0-9]\+\)\].*$@\1@g')
#}

## for tmux
bindkey -r '^T' #unbind





