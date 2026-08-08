------------------
---- PLUGINS -----
------------------

-- Check and configure Hyprbars if loaded
local _, err_hyprbars = hl.get_config("plugin.hyprbars.bar_height")
if not (err_hyprbars and string.find(err_hyprbars, "unknown config key")) then
    hl.config({
        plugin = {
            hyprbars = {
                bar_height = 20,
                bar_color = "rgba(1e1e2eff)",
                ["col.text"] = "rgba(cdd6f4ff)",
                bar_text_size = 10,
                bar_text_font = "JetBrainsMono Nerd Font",
                ["hyprbars-button"] = {
                    "rgba(f38ba8ff), 10, , hyprctl dispatch killactive",
                    "rgba(a6e3a1ff), 10, , hyprctl dispatch togglefloating",
                }
            }
        }
    })
end

-- Check and configure Hyprexpo if loaded
local _, err_hyprexpo = hl.get_config("plugin.hyprexpo.columns")
if not (err_hyprexpo and string.find(err_hyprexpo, "unknown config key")) then
    hl.config({
        plugin = {
            hyprexpo = {
                columns = 3,
                gap_size = 5,
                bg_col = "rgba(111111ff)",
                workspace_method = "center current",
                enable_gesture = true,
                gesture_distance = 300,
                gesture_positive = true,
            }
        }
    })
end

-- Check and configure Hyprspace if loaded
local _, err_hyprspace = hl.get_config("plugin.hyprspace.gesture_overview_enable")
if not (err_hyprspace and string.find(err_hyprspace, "unknown config key")) then
    hl.config({
        plugin = {
            hyprspace = {
                gesture_overview_enable = true,
            }
        }
    })
end
