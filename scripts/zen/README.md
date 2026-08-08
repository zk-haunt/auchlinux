# Zen Browser Config

Browser profile customizations — restyled UI chrome and a few prefs — kept in
the repo so a fresh install can be rebuilt in one command.

## What's here

```
scripts/zen/
├── deploy-zen-config.sh    copies the assets below into your live profile
└── userconfig/
    ├── user.js             3 prefs (one of them mandatory, see below)
    └── chrome/
        ├── userChrome.css  676 lines — browser UI restyling
        └── userContent.css stub, currently all commented out
```

**`user.js`** sets three preferences:

| Pref | Why |
|---|---|
| `toolkit.legacyUserProfileCustomizations.stylesheets=true` | **Required.** Without it Firefox/Zen ignores `userChrome.css` entirely. |
| `browser.tabs.tabmanager.enabled=false` | Drops the tab-list dropdown button from the tab strip. |
| `gfx.webrender.all=true` | Forces GPU compositing. |

**`userChrome.css`** is the actual theme: 36px rounded tabs, custom urlbar
heights, 30px button rounding, hidden tab lines, 0.4s animation timing.

**`userContent.css`** does nothing today. Its one rule — setting page
backgrounds to a blurred wallpaper image — is commented out. Kept as a hook in
case you want it back.

## Usage

```bash
./scripts/zen/deploy-zen-config.sh
```

Then **restart Zen**. `userChrome.css` is read once at startup, and `user.js` is
applied to prefs at startup too, so nothing takes effect in a running browser.

The script:

1. Resolves which profile Zen actually launches with (see below).
2. Backs up the profile's existing `chrome/` and `user.js` to
   `~/.config/cfg_backups/<timestamp>_zen/` before touching anything.
3. Copies in the two stylesheets and `user.js`.

It's re-runnable — each run makes a fresh timestamped backup, so overwriting is
always recoverable.

## Profile resolution

`~/.config/zen/` can hold several profiles, and picking the wrong one means
editing files the browser never reads. The script checks `installs.ini` first,
then falls back to the `Default=1` flag in `profiles.ini`.

That order matters on this machine. Two profiles exist:

- `kd92yfh1.Default (release)` — the real one, pinned by `installs.ini`
- `ikoddnxp.Default Profile` — empty, but flagged `Default=1` in `profiles.ini`

`installs.ini` is per-installation and wins at launch, so `profiles.ini`'s flag
is stale here. Trusting it would deploy into the dead profile.

## Extensions

Not managed here. Install them yourself from `about:addons`.

The repo used to ship five `.xpi` files that this script dropped into the
profile; they were removed. Bundling extensions means silently carrying whatever
version was vendored, and `security.md` treats extension count as attack
surface — worth a deliberate choice each time rather than a default.

## Caveats

**This CSS is Firefox chrome, not Zen chrome.** It was written against stock
Firefox and contains zero `zen-*` selectors. Zen's frontend is a substantial
rework of Firefox's — its own tabs, sidebar, and workspace widgets — so some of
these 676 lines likely target elements Zen renders differently or not at all. It
has not been verified against Zen 1.21.

**No theming integration.** Colors are static. There are no wallbash/matugen
hooks and no `@import` of generated palettes, so unlike waybar/rofi/gtk the
browser won't follow your wallpaper accent.

**Zen has its own Mods system**, which writes `chrome/zen-themes.css` in the
profile and is configured from Zen's settings UI. It's independent of these
files and won't conflict — but for Zen-specific styling it's the better-supported
path, and worth considering before investing further in this bundle.
