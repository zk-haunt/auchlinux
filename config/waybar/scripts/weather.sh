#!/usr/bin/env bash
# Weather for Waybar (JSON) and Hyprlock (plain label), via wttr.in.
# Location is auto-detected by IP; override by exporting WEATHER_LOCATION.
# Result is cached 15 min so neither the bar nor the lockscreen hammers wttr.in.
#
#   weather.sh json    → Waybar custom module  ({"text","tooltip","class"})
#   weather.sh label   → one-line text for a Hyprlock label
set -uo pipefail

mode="${1:-json}"
loc="${WEATHER_LOCATION:-}"
cache="$HOME/.cache/waybar-weather.json"
mkdir -p "$HOME/.cache"

# Refresh the cache if missing or older than 15 minutes.
if [ ! -f "$cache" ] || [ "$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))" -gt 900 ]; then
    if curl -fsS --max-time 10 "https://wttr.in/${loc}?format=j1" -o "$cache.tmp" 2>/dev/null \
        && jq -e . "$cache.tmp" >/dev/null 2>&1; then
        mv "$cache.tmp" "$cache"
    else
        rm -f "$cache.tmp"
    fi
fi

if [ ! -f "$cache" ]; then
    [ "$mode" = json ] && echo '{"text":"󰅤","tooltip":"Weather unavailable","class":"weather"}'
    [ "$mode" = label ] && echo "󰅤  weather unavailable"
    exit 0
fi

# ── Pull the fields we need ───────────────────────────────────────────────
read -r temp feels desc humidity wind city region < <(
    jq -r '
        .current_condition[0] as $c |
        (.nearest_area[0] // {}) as $a |
        [ $c.temp_C, $c.FeelsLikeC, $c.weatherDesc[0].value,
          $c.humidity, $c.windspeedKmph,
          ($a.areaName[0].value // "—"), ($a.region[0].value // "") ]
        | @tsv' "$cache"
)
read -r tmin tmax < <(jq -r '.weather[0] | [.mintempC, .maxtempC] | @tsv' "$cache")

# ── Nerd-Font icon from the condition description ─────────────────────────
icon=""
d="$(echo "$desc" | tr '[:upper:]' '[:lower:]')"
case "$d" in
    *thunder*|*storm*)          icon="" ;;
    *snow*|*sleet*|*blizzard*)  icon="" ;;
    *rain*|*drizzle*|*shower*)  icon="" ;;
    *fog*|*mist*|*haze*)        icon="" ;;
    *overcast*|*cloud*)         icon="" ;;
    *partly*)                   icon="" ;;
    *sunny*|*clear*)            icon="" ;;
    *)                          icon="" ;;
esac

if [ "$mode" = label ]; then
    printf '%s  %s°C  %s\n' "$icon" "$temp" "$desc"
    exit 0
fi

# JSON for Waybar (text on the bar + rich tooltip).
where="$city"; [ -n "$region" ] && where="$city, $region"
tooltip="$(printf '%s — %s°C (feels %s°C)\n%s\n  Humidity: %s%%   Wind: %s km/h\n  Today: %s°C / %s°C' \
    "$where" "$temp" "$feels" "$desc" "$humidity" "$wind" "$tmin" "$tmax")"

jq -cn --arg text "$icon  ${temp}°" --arg tt "$tooltip" \
    '{text:$text, tooltip:$tt, class:"weather"}'
