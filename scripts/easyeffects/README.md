# EasyEffects — system-wide audio effects

Real-time EQ, bass enhancement and other effects applied to **all** audio
coming out of the machine, not per-app. Optional: nothing else in the repo
depends on it, and `install-packages.sh` deliberately doesn't install it.

## Install

```bash
./scripts/easyeffects/easyeffects.sh
```

Installs EasyEffects plus the LV2 plugin packages its presets need, then copies
the bundled presets into place. Needs sudo, so run it in your own terminal.

Already installed and just want the presets refreshed?

```bash
./scripts/easyeffects/easyeffects.sh presets
```

## Using it

1. Launch `easyeffects`.
2. Click **Presets** (bottom-left of the window).
3. Under **Output**, pick a preset and hit **Load**.
4. Play something and use the **power toggle** (top-left) to A/B it — that
   bypasses the whole chain, which is the only real way to judge a preset.

Effects apply to every application automatically; EasyEffects inserts itself as
a virtual PipeWire sink, so there's nothing to configure per-app.

Confirm audio is actually routed through it:

```bash
pactl list sink-inputs | grep -i sink
```

Your player should list EasyEffects as its sink rather than the hardware
`alsa_output...` device.

### Bundled presets

| Preset | Chain |
|---|---|
| **Perfect EQ** | equalizer — a general-purpose corrective EQ |
| **Bass Boosted** | equalizer → convolver → bass_enhancer → crossfeed → maximizer |

### Autostart

`config/hypr/hyprland/autostart.lua` starts EasyEffects as a background service
(`--gapplication-service`) on login, so effects apply without keeping the window
open. It's guarded by `command -v easyeffects`, so it's a silent no-op until
this script installs it — no need to edit anything when you're not using it.

## Two things that will bite you

**EasyEffects ships no DSP of its own.** Every effect is an LV2 plugin from a
separate package, and a preset **silently drops** any effect whose provider
isn't installed — no error, the effect just doesn't appear in the chain. That's
why the script installs all four packages together:

| Package | Provides |
|---|---|
| `easyeffects` | the app itself |
| `lsp-plugins-lv2` | equalizer, compressor, delay, loudness |
| `calf` | limiter, exciter, bass enhancer |
| `zam-plugins-lv2` | maximizer |

If an effect is missing from a loaded preset, a plugin package is missing.

**Version 8 moved the preset directory.** Presets now live in
`~/.local/share/easyeffects/output/`; 7.x used `~/.config/easyeffects/`, which
8.x also repurposed for its live settings database (`~/.config/easyeffects/db/`).
Two consequences:

- This script writes to the 8.x location. Presets dropped in the old path are
  silently ignored — the app loads nothing and shows "No Effects".
- **Never rsync over `~/.config/easyeffects/`.** That would wipe the running
  configuration in `db/`. `apply-config.sh` used to sync this folder and no
  longer does, for exactly that reason.

## Theming

EasyEffects 8 is a Qt Quick / Kirigami app, so **Kvantum and qt6ct don't style
it** — those only apply to QtWidgets. Its colours come from the `[Colors:*]`
groups in `~/.config/kdeglobals`, which this repo ships as a complete
Catppuccin Mocha set (see `config/kdeglobals`).

If EasyEffects ever renders **white**, that file's colour groups are missing or
incomplete — Kirigami falls back to Breeze Light rather than erroring. Re-run
`./scripts/apply-config.sh` to restore it.
