export PATH="${PATH}:${HOME}/scripts"
export PATH="${PATH}:${HOME}/scripts/emacs"
export PAGER="emacs-pager"
if command -v nix >/dev/null 2>&1; then
export PATH="${PATH}:${HOME}/scripts/nixos"
fi
if command -v pacman >/dev/null 2>&1; then
export PATH="${PATH}:${HOME}/scripts/archlinux"
fi

cd() {
    command cd "$@" || return
    HOST_OS_T=$(uname)
    PS1="($HOST_OS_T)@$PWD/$ "
}

cd $PWD


# Automatically start X on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi

