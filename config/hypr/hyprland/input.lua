---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

hl.gesture({
    fingers = 4,
    direction = "up",
    action = "cursor_zoom",
    zoom_level = 1.5,
    mode = "mult"
})

hl.gesture({
    fingers = 4,
    direction = "down",
    action = "cursor_zoom",
    zoom_level = -1.5,
    mode = "mult"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = 0.7,
})
