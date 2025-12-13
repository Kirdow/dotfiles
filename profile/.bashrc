#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias web='w3m duckduckgo.com/lite/'
PS1='[\u@\h \W]\$ '

if [[ -d "$HOME/.local/share/bin" ]]; then
	export PATH="$HOME/.local/share/bin:$PATH"
fi

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
[[ -f "/usr/share/nvm/init-nvm.sh" ]] && . /usr/share/nvm/init-nvm.sh

dev() {
    if [[ ! -d "$HOME/Documents/dev/" ]]; then
        echo "Dev directory not found"
        return
    fi

    if [ -z "$1" ]; then
        ls -A ~/Documents/dev
    elif [ -z "$2" ]; then
        ls -A ~/Documents/dev/"$1"
    else
        cd ~/Documents/dev/"$1"/"$2"
    fi
}

# Commented out (unused)
: <<'COMMENT'
fastfetch () {
    NONE=true

    for arg in "$@"; do
        case $arg in
        --logo)
        NONE=false
        shift
        ;;
        esac
    done

    if [ "$NONE" = true ]; then
        $(which fastfetch) --logo none "$@"
    else
        $(which fastfetch) "$@"
    fi
}
COMMENT

if [[ ! -d "$HOME/probe" ]]; then
    mkdir -p ~/probe
fi

probe() {
    if [ -z "$1" ]; then
        # ls -a ~/probe | tail +3 | awk '{ t = t $1 " " } END { print t }'
        ls -A ~/probe
    else
        cd ~/probe/"$1"
    fi
}

ndev() {
    if [[ ! -d "$HOME/Documents/dev/" ]]; then
        echo "Dev directory not found"
        return
    fi

    if [ -z "$1" ]; then
        dev
    elif [ -z "$2" ]; then
        dev "$1"
    else
        dev "$1" "$2"
        nvim
    fi
}

ndevr() {
    if [[ ! -d "$HOME/Documents/dev/" ]]; then
        echo "Dev directory not found"
        return
    fi

    first="$1"
    second="$2"
    retpoint="$(pwd)"

    ndev "$first" "$second"

    cd "$retpoint"
}

allgit() {
    git branch -r \
        | grep -v '\->' \
        | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" \
        | while read remote; do \
            git branch --track "${remote#orogin/}" "$remote"; \
          done
    git fetch --all
    git pull --all
}

# Get line $1 in command output
line() {
    head -$1 | tail -1
}

# Alias to view an image in kitty
alias img='kitten icat --align=left'

alias grepline='line'
alias getline='line'

# Unused dotfiles git wrapper
# alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Set preferred editor to neovim
export EDITOR=nvim

# pnpm
if [[ -d "$HOME/.local/share/pnpm" ]]; then
    export PNPM_HOME="/home/kirdow/.local/share/pnpm"
    case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
    esac
fi
# pnpm end

# Alias for running protontricks when installed through flatpak
alias protontricks='flatpak run com.github.Matoking.protontricks'

# Set the currently installed vulkan version.
VULKAN_VERSION="1.3.296.0"

# Set up environment for the installed vulkan version.
if [ -f "$HOME/opt/vulkan/$VULKAN_VERSION/setup-env.sh" ]; then
    . $HOME/opt/vulkan/$VULKAN_VERSION/setup-env.sh
fi

# Add Clai to path if it exists and is built
if [ -d "$HOME/probe/clai/build/debug" ]; then
    PATH="$HOME/probe/clai/build/debug:$PATH"
    alias clai="Clai"
fi

# Add speedtest-cli to path if it exists
if [ -f "$HOME/Apps/speedtest/speedtest" ]; then
    PATH="$HOME/Apps/speedtest:$PATH"
fi

# Unset above VULKAN_VERSION as it may be used by wrapper scripts in other parts of the system. It's NOT a global variable.
unset VULKAN_VERSION

# secure-askpass configuration
if [[ -f "$HOME/probe/askpass/askpass" ]]; then
    export SUDO_ASKPASS="$HOME/probe/askpass/askpass"
fi

#if [[ -f "/usr/bin/fastfetch" ]]; then
    # /usr/bin/fastfetch --pipe false --logo none --structure OS:Kernel:Shell:Memory | awk '{ print "    " $0; }'
#fi
