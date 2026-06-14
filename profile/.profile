if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

if [ -f "/usr/share/nvm/init-nvm.sh" ]; then
    . /usr/share/nvm/init-nvm.sh
fi

if [ -f "/usr/bin/kitty" ]; then
    export TERMINAL=/usr/bin/kitty
fi

if [ -d "$HOME/.local/share/bin" ]; then
    export PATH="$HOME/.local/share/bin:$PATH"
fi

[ -f "/home/kirdow/.ghcup/env" ] && . "/home/kirdow/.ghcup/env" # ghcup-env
