    # auchctl/auchctl tab completion
    if command -v auchctl &>/dev/null; then
        compdef _auchctl auchctl
        eval "$(auchctl completion zsh)"
    fi
