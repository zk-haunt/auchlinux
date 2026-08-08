-- ----------------------------------------------------
-- Hyprland Lua Scripts & Custom Functions
-- ----------------------------------------------------

local M = {}

-- Toggle Game Mode (Performance vs. Aesthetic Mode)
function M.toggle_gamemode()
    local home = os.getenv("HOME") or "/home/newpr"
    local anims = hl.get_config("animations.enabled")
    if anims then
        hl.config({
            animations = { enabled = false },
            general = {
                gaps_in = 2,
                gaps_out = 2,
                border_size = 1
            },
            decoration = {
                shadow = { enabled = false },
                blur = { enabled = false },
                rounding = 0
            }
        })
        -- Switch waybar to the lightweight minimal bar while gaming
        os.execute(home .. "/.config/waybar/scripts/waybar-theme min >/dev/null 2>&1 &")
        os.execute("notify-send -a 'Game Mode' -i 'dialog-information' -u low 'Game Mode' 'Performance Mode Enabled (Effects, Gaps & Borders Reduced)' &")
    else
        hl.config({
            animations = { enabled = true },
            general = {
                gaps_in = 5,
                gaps_out = 10,
                border_size = 2
            },
            decoration = {
                shadow = { enabled = true },
                blur = { enabled = true },
                rounding = 10
            }
        })
        -- Restore the full auch bar when leaving game mode
        os.execute(home .. "/.config/waybar/scripts/waybar-theme auch >/dev/null 2>&1 &")
        os.execute("notify-send -a 'Game Mode' -i 'dialog-information' -u low 'Game Mode' 'Aesthetic Mode Restored' &")
    end
end

-- New Game Mode (canonical) — ports lol/HyDE's gaming workflow to this lua setup.
-- lol does: ON = `hyprctl keyword source gaming.conf`, OFF = `hyprctl reload
-- config-only`. `hyprctl keyword` is disabled here ("non-legacy parser"), so we
-- apply the same effects through the lua API and revert with reload config-only
-- (which restores everything from the persistent config and drops the runtime
-- rules we add). Mirrors lol's gaming.conf: rounding 0, no shadow/blur/anims,
-- zero gaps, all windows opaque, and — the bit you wanted — a layerrule that
-- kills blur + animations on the rofi / waybar / notification layers too.
function M.toggle_gamemode2()
    local home = os.getenv("HOME") or "/home/newpr"
    local rt   = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
    local lock = rt .. "/hypr/gamemode.lck"
    local f = io.open(lock, "r")
    if f then
        -- ── Game mode is ON → turn it OFF ────────────────────────────────
        f:close()
        os.remove(lock)
        -- Restore the full config (clears the runtime config/layer/window rules).
        os.execute("hyprctl reload config-only -q")
        os.execute(home .. "/.config/waybar/scripts/waybar-theme auch >/dev/null 2>&1 &")
        os.execute("notify-send -a 'Game Mode' -i 'dialog-information' -u low 'Game Mode' 'Aesthetic Mode Restored' &")
    else
        -- ── Game mode is OFF → turn it ON ────────────────────────────────
        os.execute("mkdir -p " .. rt .. "/hypr && touch " .. lock)
        hl.config({
            animations = { enabled = false },
            general    = { gaps_in = 0, gaps_out = 0, border_size = 1 },
            decoration = {
                shadow = { enabled = false },
                blur   = { enabled = false, xray = true },
                rounding = 0,
                active_opacity = 1, inactive_opacity = 1, fullscreen_opacity = 1,
            },
        })
        -- Force every window opaque (beats the per-app opacity rules).
        hl.window_rule({ name = "gamemode-opaque", match = { class = "(.*)" }, opacity = "1.0 1.0 1.0" })
        -- Flatten the shell layers too: no blur, no animations on rofi/waybar/notifs.
        hl.layer_rule({
            name   = "gamemode",
            blur   = false,
            no_anim = true,
            match  = { namespace = "^(rofi|notifications|swaync-(notification-window|control-center)|logout_dialog|waybar|.*www-daemon)$" },
        })
        os.execute(home .. "/.config/waybar/scripts/waybar-theme min >/dev/null 2>&1 &")
        os.execute("notify-send -a 'Game Mode' -i 'dialog-information' -u low 'Game Mode' 'Performance Mode On (flat corners, no blur/anims)' &")
    end
end

-- Active Window Audio Muter (Native Lua implementation)
function M.mute_active_window()
    -- Get active window details
    local handle = io.popen("hyprctl activewindow -j")
    if not handle then return end
    local active_json = handle:read("*a")
    handle:close()
    
    -- Extract values using helper jq commands (safe for spaces and special characters)
    local function jq_extract(json, filter)
        local h = io.popen("echo '" .. json:gsub("'", "'\\''") .. "' | jq -r '" .. filter .. "'")
        if not h then return "" end
        local val = h:read("*l")
        h:close()
        return val or ""
    end

    local active_pid = jq_extract(active_json, ".pid")
    local active_title = jq_extract(active_json, ".title")
    local active_class = jq_extract(active_json, ".class"):lower()

    if active_pid == "null" or active_pid == "" then
        hl.dsp.exec_cmd("notify-send -a 'Mute Window' -u low 'Mute Window' 'No active window found'")
        return
    end

    -- Get all PIDs in the tree of active window
    local tree_handle = io.popen("(echo '" .. active_pid .. "'; pstree -p '" .. active_pid .. "' | grep -o '[0-9]\\+') | sort -u")
    if not tree_handle then return end
    local tree_pids_str = tree_handle:read("*a")
    tree_handle:close()
    
    local tree_pids = {}
    for pid in tree_pids_str:gmatch("%d+") do
        tree_pids[pid] = true
    end

    -- Read and parse sink inputs using tab delimiter
    local awk_cmd = [[pactl list sink-inputs | awk '
BEGIN { id = ""; pid = ""; app_name = ""; media_name = "" }
/^Sink Input #/ {
    if (id != "") { print id "\t" pid "\t" app_name "\t" media_name }
    id = substr($3, 2); pid = ""; app_name = ""; media_name = ""
}
/application.process.id =/ {
    val = $0; sub(/^.*application.process.id = "/, "", val); sub(/"$/, "", val); pid = val
}
/application.name =/ {
    val = $0; sub(/^.*application.name = "/, "", val); sub(/"$/, "", val); app_name = tolower(val)
}
/media.name =/ {
    val = $0; sub(/^.*media.name = "/, "", val); sub(/"$/, "", val); media_name = val
}
END {
    if (id != "") { print id "\t" pid "\t" app_name "\t" media_name }
}']]

    local inputs_handle = io.popen(awk_cmd)
    if not inputs_handle then return end
    
    local candidates = {}
    for line in inputs_handle:lines() do
        local id, pid, app_name, media_name = line:match("([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\n]*)")
        if id then
            local match_found = false
            if tree_pids[pid] then
                match_found = true
            elseif active_class ~= "" and active_class ~= "null" and app_name ~= "" then
                if app_name == active_class or active_class:find(app_name, 1, true) or app_name:find(active_class, 1, true) then
                    match_found = true
                end
            end
            
            if match_found then
                table.insert(candidates, { id = id, media_name = media_name })
            end
        end
    end
    inputs_handle:close()

    if #candidates == 0 then
        hl.dsp.exec_cmd("notify-send -a 'Mute Window' -u low -i 'audio-volume-muted' 'Mute Window' 'No audio stream found for the active window'")
        return
    end

    -- Narrow down by media name matching window title
    local matched_ids = {}
    if active_title ~= "" and active_title ~= "null" then
        local lc_title = active_title:lower()
        for _, cand in ipairs(candidates) do
            if cand.media_name ~= "" then
                local lc_media = cand.media_name:lower()
                if lc_title:find(lc_media, 1, true) or lc_media:find(lc_title, 1, true) then
                    table.insert(matched_ids, cand.id)
                end
            end
        end
    end

    local final_ids = matched_ids
    if #final_ids == 0 then
        -- Fallback: use all app candidates
        final_ids = {}
        for _, cand in ipairs(candidates) do
            table.insert(final_ids, cand.id)
        end
    end

    -- Toggle mute
    local muted_count = 0
    local unmuted_count = 0
    
    for _, id in ipairs(final_ids) do
        local status_handle = io.popen("pactl list sink-inputs | awk -v target_id='" .. id .. "' '/^Sink Input #/ { id = substr($3, 2) } /Mute:/ { if (id == target_id) { print $2; exit } }'")
        if status_handle then
            local current_mute = status_handle:read("*l")
            status_handle:close()
            
            if current_mute == "yes" then
                os.execute("pactl set-sink-input-mute '" .. id .. "' no")
                unmuted_count = unmuted_count + 1
            else
                os.execute("pactl set-sink-input-mute '" .. id .. "' yes")
                muted_count = muted_count + 1
            end
        end
    end

    -- Desktop notification
    local display_title = (active_title ~= "" and active_title ~= "null") and active_title:sub(1, 30) or "Active Window"
    if muted_count > 0 then
        hl.dsp.exec_cmd("notify-send -a 'Mute Window' -u low -i 'audio-volume-muted' 'Muted window audio' '" .. display_title:gsub("'", "'\\''") .. "'")
    elseif unmuted_count > 0 then
        hl.dsp.exec_cmd("notify-send -a 'Mute Window' -u low -i 'audio-volume-high' 'Unmuted window audio' '" .. display_title:gsub("'", "'\\''") .. "'")
    end
end

-- Toggle Zsh Theme Mode (cycles dynamically using Lua script)
function M.toggle_zsh_theme()
    local home = os.getenv("HOME") or "/home/newpr"
    os.execute("lua " .. home .. "/.config/hypr/hyprland/luascript/zsh-theme.lua cycle &>/dev/null &")
end

-- Toggle Rofi Theme Mode (cycles dynamically using Lua script)
-- NOTE: The trailing & backgrounds the process so os.execute() returns
-- immediately without blocking the Hyprland compositor.
function M.toggle_rofi_theme()
    local home = os.getenv("HOME") or "/home/newpr"
    os.execute("lua " .. home .. "/.config/hypr/hyprland/luascript/rofi-theme.lua cycle &>/dev/null &")
end

-- Smart-move active window: floating windows nudge by pixels (relative, since
-- the lua window.move({x,y}) is absolute we add the delta to the current pos),
-- tiled windows move in the layout direction. Replaces a broken approach that
-- shelled out to `hyprctl dispatch moveactive`, which this lua-Hyprland rejects.
function M.smart_move(dx, dy, dir)
    local h = io.popen("hyprctl activewindow -j 2>/dev/null")
    local data = h and h:read("*a") or ""
    if h then h:close() end
    if data:match('"floating"%s*:%s*true') then
        local x = tonumber(data:match('"at"%s*:%s*%[%s*(-?%d+)'))
        local y = tonumber(data:match('"at"%s*:%s*%[%s*-?%d+%s*,%s*(-?%d+)'))
        if x and y then
            hl.dispatch(hl.dsp.window.move({ x = x + dx, y = y + dy }))
        end
    else
        hl.dispatch(hl.dsp.window.move({ direction = dir }))
    end
end

-- Pin active window: a window must be floating to be pinned, so float it first
-- (only if it isn't already), then toggle pin. A pinned window stays visible on
-- every workspace. (Native window.pin() alone silently no-ops on tiled windows.)
function M.pin_window()
    local h = io.popen("hyprctl activewindow -j 2>/dev/null")
    local data = h and h:read("*a") or ""
    if h then h:close() end
    local floating = data:match('"floating"%s*:%s*(%a+)')
    local pinned = data:match('"pinned"%s*:%s*(%a+)')
    if pinned ~= "true" and floating ~= "true" then
        hl.dispatch(hl.dsp.window.float())   -- togglefloating → make it floating
    end
    hl.dispatch(hl.dsp.window.pin())         -- toggle pin
end

-- Expose globally for convenience in other modules
_G.luafunctions = M

return M
