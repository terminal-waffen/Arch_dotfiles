#!/usr/bin/env bash

set -u

PROMPT="Wi-Fi"

notify() {
    notify-send "Network" "$1"
}

wifi_on() {
    nmcli radio wifi | grep -qi "^enabled$"
}

current_wifi() {
    nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes"{print $2; exit}'
}

rescan_wifi() {
    nmcli device wifi rescan >/dev/null 2>&1
}

build_wifi_list() {
    nmcli --colors no -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list | awk -F: '
    {
        inuse=$1
        ssid=$2
        security=$3
        signal=$4

        if (ssid == "") ssid = "<hidden>"

        if (inuse == "*") {
            prefix="󰖩 [connected]"
        } else if (security == "" || security == "--") {
            prefix="󰖪 [open]"
        } else {
            prefix="󰖪 [secured]"
        }

        print prefix " " ssid " [" signal "%]"
    }' | awk '!seen[$0]++'
}

extract_ssid() {
    echo "$1" | sed -E 's/^.*\] (.*) \[[0-9]+%\]$/\1/'
}

connect_wifi() {
    local ssid="$1"

    if [ "$ssid" = "<hidden>" ]; then
        notify "Versteckte Netzwerke sind in diesem Menü nicht direkt unterstützt"
        return
    fi

    # Erst normal versuchen (klappt bei bekannten oder offenen Netzen)
    if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
        notify "Verbunden mit $ssid"
        return
    fi

    # Passwort abfragen
    local password
    password=$(printf "" | fuzzel --dmenu -p "Passwort für $ssid")
    [ -z "${password:-}" ] && return

    if nmcli device wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
        notify "Verbunden mit $ssid"
    else
        notify "Verbindung fehlgeschlagen: $ssid"
    fi
}

disconnect_current_wifi() {
    local active_con
    active_con="$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1; exit}')"

    if [ -n "${active_con:-}" ]; then
        nmcli connection down "$active_con" >/dev/null 2>&1 \
            && notify "WLAN getrennt" \
            || notify "Trennen fehlgeschlagen"
    else
        notify "Kein aktives WLAN"
    fi
}

main_menu() {
    local power_line scan_line current_line wifi_list menu choice current

    if wifi_on; then
        power_line="󰖩  Wi-Fi: ON"
    else
        power_line="󰖪  Wi-Fi: OFF"
    fi

    current="$(current_wifi)"
    if [ -n "${current:-}" ]; then
        current_line="󰤨  Aktuell: $current"
    else
        current_line="󰤭  Aktuell: keines"
    fi

    scan_line="󰑐  Neu scannen"

    wifi_list=""
    if wifi_on; then
        wifi_list="$(build_wifi_list)"
    fi

    menu="$power_line"$'\n'
    menu+="$current_line"$'\n'
    menu+="$scan_line"$'\n'
    menu+="────────────────"$'\n'
    menu+="$wifi_list"

    choice="$(printf "%s" "$menu" | sed '/^$/d' | fuzzel --dmenu -p "$PROMPT")"
    [ -z "${choice:-}" ] && exit 0

    case "$choice" in
        "󰖩  Wi-Fi: ON")
            nmcli radio wifi off >/dev/null 2>&1 && notify "Wi-Fi ausgeschaltet"
            ;;
        "󰖪  Wi-Fi: OFF")
            nmcli radio wifi on >/dev/null 2>&1 && notify "Wi-Fi eingeschaltet"
            rescan_wifi
            ;;
        "󰑐  Neu scannen")
            rescan_wifi
            notify "WLAN neu gescannt"
            ;;
        󰤨*"Aktuell:"*)
            if [ -n "${current:-}" ]; then
                disconnect_current_wifi
            fi
            ;;
        󰤭*"Aktuell: keines"*)
            :
            ;;
        *)
            local ssid selected_current
            ssid="$(extract_ssid "$choice")"
            selected_current="$(current_wifi)"

            [ -z "${ssid:-}" ] && return

            if [ "$ssid" = "$selected_current" ]; then
                disconnect_current_wifi
            else
                connect_wifi "$ssid"
            fi
            ;;
    esac
}

while true; do
    main_menu
done
