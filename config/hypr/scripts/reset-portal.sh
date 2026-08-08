#!/usr/bin/env bash

# Reset and restart xdg-desktop-portal to fix frozen screen share or file pickers
notify-send -a "System" -i "dialog-information" "Portal Reset" "Restarting portal services..."

# Terminate running portal processes
killall -q xdg-desktop-portal-hyprland
killall -q xdg-desktop-portal-gnome
killall -q xdg-desktop-portal-kde
killall -q xdg-desktop-portal-lxqt
killall -q xdg-desktop-portal-wlr
killall -q xdg-desktop-portal

sleep 1

# Restart services
/usr/lib/xdg-desktop-portal-hyprland &
sleep 2
/usr/lib/xdg-desktop-portal &

notify-send -a "System" -i "dialog-information" "Portal Reset" "Portal services successfully restarted!"
