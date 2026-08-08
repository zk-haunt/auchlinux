#!/usr/bin/env bash
# =============================================================================
#  Dev toolchains for AuchLinux — Node (via nvm), Rust (rustup), Go
#
#  Usage:
#     ./scripts/dev-utils.sh            # install everything missing
#     ./scripts/dev-utils.sh --status   # show what's installed, change nothing
#
#  Safe to re-run (idempotent) — each step is skipped if already present.
#
#  Node goes through nvm rather than pacman so you can hold different versions
#  per project. Rust and Go come from pacman so `pacman -Syu` keeps them current;
#  rustup still manages the toolchains underneath.
#
#  Shell wiring lives in config/zsh/conf.d/50-dev.zsh (repo-tracked, deployed by
#  apply-config.sh). Note that nvm's own installer appends to ~/.zshrc, which
#  apply-config.sh overwrites from the repo — so this script deliberately skips
#  that and relies on the conf.d file instead.
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NVM_DIR="$HOME/.nvm"
NVM_VERSION="v0.40.1"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
section() { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }

if [[ $EUID -eq 0 ]]; then
    warn "Run this as your normal user (it uses sudo where needed)."
    exit 1
fi

# ─── --status ────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
    have() { command -v "$1" &>/dev/null && echo "✓ $("$1" --version 2>/dev/null | head -1)" || echo "✗ not installed"; }
    echo -e "\n${BOLD}Dev toolchain status${RESET}"
    printf "  %-10s %s\n" "nvm"   "$([[ -s $NVM_DIR/nvm.sh ]] && echo "✓ $NVM_DIR" || echo "✗ not installed")"
    printf "  %-10s %s\n" "node"  "$(have node)"
    printf "  %-10s %s\n" "npm"   "$(have npm)"
    printf "  %-10s %s\n" "rustup" "$(have rustup)"
    printf "  %-10s %s\n" "cargo" "$(have cargo)"
    printf "  %-10s %s\n" "go"    "$(have go)"
    printf "  %-10s %s\n" "shell hook" \
        "$([[ -f $HOME/.config/zsh/conf.d/50-dev.zsh ]] && echo "✓ deployed" || echo "✗ run apply-config.sh zsh")"
    echo
    exit 0
fi

# ─── 1. Rust ─────────────────────────────────────────────────────────────────
# Arch ships ONE package, `rustup`, which provides rustc/cargo/rustup. There is
# no separate `rust` package to install — `pacman -Q rust` resolves to rustup.
section "Rust"
if command -v rustup &>/dev/null; then
    ok "rustup already installed"
else
    info "Installing rustup from pacman..."
    sudo pacman -S --needed --noconfirm rustup
fi

# Arch's rustup ships with NO toolchain selected — `cargo` exists but errors out
# until a default is set. This is the step people miss.
if ! rustup default &>/dev/null || rustup default 2>&1 | grep -q "no default toolchain"; then
    info "Setting default toolchain to stable..."
    rustup default stable
fi
ok "rust: $(rustc --version 2>/dev/null || echo 'toolchain pending')"

# ─── 2. Go ───────────────────────────────────────────────────────────────────
section "Go"
if command -v go &>/dev/null; then
    ok "go already installed: $(go version)"
else
    info "Installing go from pacman..."
    sudo pacman -S --needed --noconfirm go
    ok "go installed: $(go version)"
fi

# ─── 3. Node LTS via nvm ─────────────────────────────────────────────────────
section "Node.js (via nvm)"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    ok "nvm already installed at $NVM_DIR"
else
    info "Installing nvm $NVM_VERSION..."
    # Download to a file first rather than piping curl into bash: on a network
    # failure the substitution would expand to nothing, the shell would exit 0,
    # and we'd report success having installed nothing.
    nvm_installer="$(mktemp)"
    trap 'rm -f "$nvm_installer"' EXIT
    if ! curl -fsSL --max-time 60 \
            "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" \
            -o "$nvm_installer"; then
        warn "Could not download the nvm installer (network?). Re-run when online."
        exit 1
    fi
    [[ -s "$nvm_installer" ]] || { warn "Downloaded nvm installer is empty."; exit 1; }

    # PROFILE=/dev/null stops nvm appending its init block to ~/.zshrc — that
    # file is repo-managed and apply-config.sh would overwrite it. Our shell
    # wiring lives in config/zsh/conf.d/50-dev.zsh instead.
    # NVM_DIR is unset for the installer: if it's exported but the directory
    # doesn't exist yet, the installer aborts ("but that directory does not
    # exist") instead of creating it.
    env -u NVM_DIR PROFILE=/dev/null bash "$nvm_installer"

    [[ -s "$NVM_DIR/nvm.sh" ]] || { warn "nvm install did not produce $NVM_DIR/nvm.sh"; exit 1; }
    ok "nvm installed"
fi

# Load nvm into THIS shell so we can install node with it.
export NVM_DIR
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

if nvm ls --no-colors 2>/dev/null | grep -q "v[0-9]"; then
    ok "node already installed: $(node --version 2>/dev/null)"
else
    info "Installing Node LTS..."
    nvm install --lts
    nvm alias default 'lts/*'
    ok "node $(node --version) / npm $(npm --version)"
fi

# ─── 4. Shell wiring ─────────────────────────────────────────────────────────
section "Shell integration"
HOOK="$HOME/.config/zsh/conf.d/50-dev.zsh"
if [[ -f "$HOOK" ]]; then
    ok "zsh hook present at $HOOK"
else
    info "Deploying zsh hook via apply-config.sh..."
    "$REPO_DIR/scripts/apply-config.sh" zsh
    [[ -f "$HOOK" ]] && ok "zsh hook deployed" || warn "Hook still missing — check config/zsh/conf.d/50-dev.zsh exists in the repo"
fi

echo
ok "Done. Open a new shell (or: exec zsh) to pick up node/cargo/go on PATH."
info "nvm is lazy-loaded — the first 'node' or 'npm' call in a shell is slightly slower."
