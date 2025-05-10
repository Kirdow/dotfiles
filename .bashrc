#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

if [[ -d "$HOME/.local/share/bin" ]]; then
	export PATH="$HOME/.local/share/bin:$PATH"
fi
. "$HOME/.cargo/env"
. /usr/share/nvm/init-nvm.sh

dev() {
    cd ~/Documents/dev/"$1"/"$2"
}

ndev() {
    dev "$1" "$2"
    nvim
}

ndevr() {
    first="$1"
    second="$2"
    retpoint="$(pwd)"

    ndev "$first" "$second"

    cd "$retpoint"
}

alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

