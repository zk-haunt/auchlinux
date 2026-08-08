#!/usr/bin/env zsh

# Load all custom module files
for file in "${ZDOTDIR:-$HOME/.config/zsh}/conf.d/"*.zsh; do
  [ -r "$file" ] && source "$file"
done
