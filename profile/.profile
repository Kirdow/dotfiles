if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

if [ -f "/usr/share/nvm/init-nvm.sh" ]; then
    . /usr/share/nvm/init-nvm.sh
fi

if [ -f "/usr/bin/kitty" ]; then
    export TERMINAL=/usr/bin/kitty
fi
