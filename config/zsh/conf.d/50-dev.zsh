#!/usr/bin/env zsh
# Dev toolchains: nvm (node/npm), rust (cargo), go.
# Installed by scripts/dev-utils.sh — this file only wires them into the shell.
#
# Every block is guarded, so on a machine without these toolchains the file is a
# no-op. That matters because .zshenv sources conf.d/*.zsh unconditionally.

# ── Rust / Go: just PATH, cheap ──────────────────────────────────────────────
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)
[[ -d "$HOME/go/bin" ]]     && path=("$HOME/go/bin" $path)

# ── nvm: lazy-loaded ─────────────────────────────────────────────────────────
# Sourcing nvm.sh costs ~200ms. .zshenv runs for EVERY zsh — including every
# `zsh -c` from a script — so loading it eagerly would tax the whole system.
# Instead define shims that replace themselves with the real thing on first use.
# Only export NVM_DIR once nvm actually exists. Exporting it unconditionally
# makes nvm's own installer abort with "You have $NVM_DIR set to ..., but that
# directory does not exist" — it treats a set-but-missing NVM_DIR as a broken
# profile rather than a fresh install.
if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    _auch_load_nvm() {
        unfunction nvm node npm npx corepack 2>/dev/null
        source "$NVM_DIR/nvm.sh"
        [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
    }
    for _auch_cmd in nvm node npm npx corepack; do
        eval "${_auch_cmd}() { _auch_load_nvm; ${_auch_cmd} \"\$@\"; }"
    done
    unset _auch_cmd
fi
