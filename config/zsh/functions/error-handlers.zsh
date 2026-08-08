function command_not_found_handler {
    local cmd="$1"
    local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' yellow='\e[1;33m' reset='\e[0m'

    printf "${green}zsh${reset}: command ${purple}not found${reset}: ${bright}'%s'${reset}\n" "$cmd"

    # Search via pacman file database (pacman -F)
    if command -v pacman &>/dev/null; then
        printf "${yellow}󰍉 Searching packages that provide '${bright}%s${yellow}'...${reset}\n" "$cmd"
        local results
        results=$(pacman -F "/usr/bin/$cmd" 2>/dev/null)
        if [[ -n "$results" ]]; then
            printf "${green} Found in:${reset}\n"
            echo "$results" | while IFS= read -r line; do
                printf "   ${bright}%s${reset}\n" "$line"
            done
            printf "${yellow}  → Install with: ${bright}sudo pacman -S <package>${reset}\n"
        else
            printf "${purple} No package found that provides '${bright}%s${purple}'.${reset}\n" "$cmd"
        fi
    fi

    return 127
}

# Function to handle initialization errors
function handle_init_error {
    if [[ $? -ne 0 ]]; then
        echo "Error during initialization. Please check your configuration."
    fi
}

function no_such_file_or_directory_handler {
    local red='\e[1;31m' reset='\e[0m'
    printf "${red}zsh: no such file or directory: %s${reset}\n" "$1"
    return 127
}
