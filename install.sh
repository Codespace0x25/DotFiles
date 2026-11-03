#!/usr/bin/env bash

set -u

# Configuration
DOTFILES="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="${HOME:?HOME is not set}"

VERBOSE=1

# Files and directories to ignore
EXCLUDES=(
    ".git"
    "install.sh"
    ".stowrc"
    "README.md"
)

log() {
    (( VERBOSE )) && printf '[install] %s\n' "$1"
}

skip() {
    local path="$1"
    local relative="${path#"$DOTFILES"/}"

    for excluded in "${EXCLUDES[@]}"; do
        [[ "$relative" == "$excluded" ]] && return 0
        [[ "$relative" == "$excluded/"* ]] && return 0
    done

    return 1
}

install_file() {
    local source="$1"
    local relative="${source#"$DOTFILES"/}"
    local target="$HOME_DIR/$relative"
    local target_dir

    target_dir="$(dirname -- "$target")"

    # Create parent directories only.
    mkdir -p -- "$target_dir"

    # Do not overwrite existing files or links.
    if [[ -e "$target" || -L "$target" ]]; then
        log "Skipping existing: $relative"
        return
    fi

    ln -s -- "$source" "$target"
    log "Linked: $relative"
}

main() {
    log "Installing dotfiles from: $DOTFILES"
    log "Target: $HOME_DIR"

    while IFS= read -r -d '' file; do
        skip "$file" && continue
        install_file "$file"
    done < <(find "$DOTFILES" -type f -print0)

    log "Installation complete."
}

main "$@"
