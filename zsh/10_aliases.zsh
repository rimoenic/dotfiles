
# ls settings
eval `dircolors -b $HOME/.dircolors`
LS_OPTIONS='-v --show-control-chars -h --color=auto'
alias ls="ls $LS_OPTIONS"
alias ll="ls -l $LS_OPTIONS"
alias la="ls -A $LS_OPTIONS"
alias lla="ls -lA $LS_OPTIONS"
alias lal='lla'

alias df='df -h'
alias pd=popd
alias gd='dirs -v; echo -n "select number: "; read newdir; cd +"$newdir"'
alias lv='lv -c'
[ -e "$(which vim)" ] && alias vi='vim'
[ -e "$(which nvim)" ] && alias vim='nvim'
alias screen='screen -U'
alias awslocal='aws --endpoint-url=http://127.0.0.1:4566 --profile localstack'

autoload -Uz zmv
alias zrename='noglob zmv -W'

export PAGER=less
alias -g L="| $PAGER"
alias -g W="| w3m -T text/html"
alias -g G="| grep"
alias -g LC="|lv|cat"

alias -s ps=gv
alias -s eps=gv
alias -s dvi=dvipdfmx
alias -s tex=platex
alias -s pdf=gv

alias ssh='env TERM=xterm-256color ssh'

alias digsakura='dig @ns1.dns.ne.jp'



function mule() {
#	/cygdrive/c/_Soft/xyzzy/xyzzycli.exe $*
	/cygdrive/c/_Soft/emacs-24.5-IME-patched/bin/runemacs.exe $*
}

function e()
{
	explorer.exe '/e,.'
}

function digsakura()
{
        dig @ns1.dns.ne.jp $*
}

function dignifty()
{
    echo $*
	if [ x$2 = "x" ]
	then
		dignifty1 $1
	else
        command=$1
        shift
        case $command in
            "primary" | "pri" | "p" | "1") dignifty1 $* ;;
            "secondary" | "sec" | "s" | "2") dignifty2 $* ;;
            *) echo !!!dig primary dns server!!!; dignifty1 $command $* ;;
        esac
	fi
}

function dignifty1()
{
        dig @202.248.130.151 $*
}

function dignifty2()
{
        dig @202.219.2.39 $*
}

function digmuumuu()
{
        dig @dns01.muumuu-domain.com $*
}

function digseeds()
{
        dig @ns1.seedsnetworks.com $*
        dig @ns1.dns-server.jp $*
}

function _whois()
{
    whois -h whois.verisign-grs.com $*
}

function rowo()
{
    roadwork --dry-run --target-zone $(basename $(readlink -f ${PWD})) $*
}

function roadwork-export()
{
    roadwork -e --split --with-soa-ns -o ${PWD}
}

function rw-del-zone()
{
    case $1 in
        --nodry)
            shift
            roadwork -a --force --target-zone $1
            ;;
        *)
            roadwork -a --dry-run --force --target-zone $1
            ;;
    esac

}
