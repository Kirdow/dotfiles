#
# ~/.bashrc
#

# secure-askpass configuration. Deliberately ABOVE the interactive guard:
# this is an environment variable, not an interactive setting, so scripts,
# cron jobs and `sudo -A` from non-interactive shells need it too.
if [[ -f "$HOME/probe/askpass/askpass" ]]; then
    export SUDO_ASKPASS="$HOME/probe/askpass/askpass"
fi

if [[ -d "$HOME/.local/share/bin" ]]; then
	export PATH="$HOME/.local/share/bin:$PATH"
fi

if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# pnpm
if [[ -d "$HOME/.local/share/pnpm" ]]; then
    export PNPM_HOME="/home/kirdow/.local/share/pnpm"
    case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
    esac
fi
# pnpm end

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias web='w3m duckduckgo.com/lite/'
alias ssh='kitten ssh'
alias externalip='curl -sS https://ysap.sh/ip'
alias ncdu='ncdu -x'

PS1='[\u@\h \W]\$ '

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
# nvm is lazy-loaded: sourcing it eagerly cost ~129ms per shell.
# The first call to any of these shims loads it for real.
if [[ -s "/usr/share/nvm/init-nvm.sh" ]]; then
    _load_nvm() {
        unset -f nvm node npm npx _load_nvm
        . /usr/share/nvm/init-nvm.sh
        nvm use default --silent
    }
    nvm()  { _load_nvm; nvm  "$@"; }
    node() { _load_nvm; node "$@"; }
    npm()  { _load_nvm; npm  "$@"; }
    npx()  { _load_nvm; npx  "$@"; }
fi

smartresize() {
    mogrify -path $3 -filter Triangle -define filter:support=2 -thumbnail $2 -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality 82 -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB $1
}

cputemp() {
    cat /sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon4/temp1_input | awk '{ print "CPU: " ($1 / 1000) "°C"; }'
}

print_args() {
  local i=0
  for arg in "$@"; do
    echo "$i: [$arg]"
    ((i++))
  done
}

branches() {
    git branch -l | wc -l | awk '{ print "This repository has " $1 " branches."; }'
}

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
        local CDP_PATH
        local TARGET
        CDP_PATH="$HOME/probe/cdp/target/dist/cdp"
        if [[ -f "$CDP_PATH" ]]; then
            TARGET=$(command $CDP_PATH)
            CDP_RC=$?
            if (( CDP_RC != 0 )); then
                echo "Failed to cd-probe."
            elif [[ -z "$TARGET" ]]; then
                return
            elif [[ ! -d "$TARGET" ]]; then
                echo "Return cd-probe path invalid."
            else
                echo "Entering $(basename "$TARGET")..."
                cd $TARGET
            fi
        else
            ls -A ~/probe
        fi
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

# Might remove later
alias hytale='cd ~/.var/app/com.hypixel.HytaleLauncher/data/Hytale/UserData/Saves/Mopds/mods/'

# Alias to view an image in kitty
alias img='kitten icat --align=left'

alias grepline='line'
alias getline='line'

# Unused dotfiles git wrapper
# alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Set preferred editor to neovim
export EDITOR=nvim

# Alias for running protontricks when installed through flatpak
alias protontricks='flatpak run com.github.Matoking.protontricks'

# Force cinny to use X11 with compositing disabled to avoid blank window
alias cinny='WEBKIT_DISABLE_COMPOSITING_MODE=1 GDK_BACKEND=x11 cinny'

# Vulkan SDK sourcing removed 2026-07-26. It exported a global
# LD_LIBRARY_PATH and VK_ADD_LAYER_PATH into every process launched from a
# shell, pinned to SDK 1.3.296.0 (Oct 2024). Mesa's system Vulkan is used
# instead. To develop against a pinned SDK again, source it per-project.

# Add Clai to path if it exists and is built
if [ -d "$HOME/probe/clai/build/debug" ]; then
    PATH="$HOME/probe/clai/build/debug:$PATH"
    alias clai="Clai"
fi

# Add new Clai
if [ -d "$HOME/probe/clai/bin" ]; then
    PATH="$HOME/probe/clai/bin:$PATH"

    # The ollama package, its unit and its binary were all removed.
    # Starting it here only triggered askpass for nothing.
    clai() {
        command clai "$@"
    }
fi

# Add khar
if [ -d "$HOME/probe/khar/build/" ]; then
    PATH="$HOME/probe/khar/build:$PATH"
fi

# Add speedtest-cli to path if it exists
if [ -f "$HOME/Apps/speedtest/speedtest" ]; then
    PATH="$HOME/Apps/speedtest:$PATH"
fi

# Add gcc-cross to path if it exists
if [ -d "$HOME/opt/cross/bin" ]; then
    PATH="$HOME/opt/cross/bin:$PATH"
fi

# Ruby user gems. Globbed rather than asking ruby, which cost ~22ms
# per shell, twice. The glob also survives ruby version bumps.
for _gemdir in "$HOME"/.local/share/gem/ruby/*/bin; do
    [[ -d "$_gemdir" ]] && export PATH="$PATH:$_gemdir"
done
unset _gemdir

#if [[ -f "/usr/bin/fastfetch" ]]; then
    # /usr/bin/fastfetch --pipe false --logo none --structure OS:Kernel:Shell:Memory | awk '{ print "    " $0; }'
#fi

[ -f "/home/kirdow/.ghcup/env" ] && . "/home/kirdow/.ghcup/env" # ghcup-env
