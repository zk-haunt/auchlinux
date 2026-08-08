#  Startup & Theme Toggle 

if [[ $- == *i* ]]; then
    # Default theme mode
    theme_mode="lol"
    if [[ -f "$HOME/.config/zsh/zsh_theme_mode" ]]; then
        theme_mode=$(cat "$HOME/.config/zsh/zsh_theme_mode" | tr -d '[:space:]')
    fi
    
    if [[ "$theme_mode" == "newpr" ]]; then
        # Newpr Style: Minimalist prompt + fastfetch
        export STARSHIP_CONFIG="$HOME/.config/starship/starship_newpr.toml"
        if command -v fastfetch >/dev/null; then
            fastfetch
        fi
    elif [[ "$theme_mode" == "onmeds" ]]; then
        # Onmeds Style: Powerline compact prompt + fastfetch
        export STARSHIP_CONFIG="$HOME/.config/starship/starship_onmeds.toml"
        if command -v fastfetch >/dev/null; then
            fastfetch
        fi
    elif [[ "$theme_mode" == "end4" ]]; then
        # End4 Style: Starship End4 + fastfetch (End4 Black layout)
        export STARSHIP_CONFIG="$HOME/.config/starship/starship_end4.toml"
        if command -v fastfetch >/dev/null; then
            fastfetch
        fi
    else
        # Lol Style: Custom prompt + fastfetch
        export STARSHIP_CONFIG="$HOME/.config/starship/starship_lol.toml"
        if command -v fastfetch >/dev/null; then
            fastfetch
        fi
    fi
fi

if [[ ${AUCH_ZSH_NO_PLUGINS} != "1" ]]; then
    #  OMZ Plugins 
    # manually add your oh-my-zsh plugins here
    plugins=(
        "sudo"
    )
fi
