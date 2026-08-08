-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Official Wiki documentation:
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- ── Cursor Styles & Size ──────────────────────────────────────
-- Set Bibata Modern Ice cursor and define size for both classic X11 and Hyprcursor themes
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")

-- ── Toolkit Backend Configurations ────────────────────────────
-- GDK: Use Wayland first, fall back to X11 if Wayland is unavailable
hl.env("GDK_BACKEND", "wayland,x11,*")

-- Qt: Force Wayland backend, fallback to X11 (xcb) if necessary
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- SDL2: Run SDL applications natively on Wayland
hl.env("SDL_VIDEODRIVER", "wayland")

-- Clutter: Tell Clutter-based applications to run on Wayland
hl.env("CLUTTER_BACKEND", "wayland")

-- ── XDG Desktop Portal & Session Specifications ───────────────
-- Ensure portal services and window systems recognize Hyprland Wayland environment
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- ── Qt Application Styling ────────────────────────────────────
-- Disable client-side window decorations on Qt applications
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Tell Qt based applications to read theme configurations from qt5ct/qt6ct
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- ── Unused / Fallback Configurations ──────────────────────────
-- env = WEATHER_LAT,xx.yyyy
-- env = WEATHER_LON,xx.yyyy
-- env = GDK_SCALE,1
-- env = QT_AUTO_SCREEN_SCALE_FACTOR,1
