#!/usr/bin/env bash

set -u

FUZZEL_PROMPT="Bluetooth"
SCAN_PID_FILE="/tmp/bluetooth-scan.pid"

notify() {
    notify-send "Bluetooth" "$1"
}

bt_powered() {
    bluetoothctl show | grep -q "Powered: yes"
}

scan_running() {
    [ -f "$SCAN_PID_FILE" ] && kill -0 "$(cat "$SCAN_PID_FILE")" 2>/dev/null
}

start_scan() {
    if scan_running; then
        notify "Scan läuft bereits"
        return
    fi

    coproc BTSCAN { bluetoothctl scan on; }
    echo "$BTSCAN_PID" > "$SCAN_PID_FILE"
    disown "$BTSCAN_PID" 2>/dev/null || true
    notify "Scan gestartet"
}

stop_scan() {
    bluetoothctl scan off >/dev/null 2>&1 || true

    if scan_running; then
        kill "$(cat "$SCAN_PID_FILE")" 2>/dev/null || true
    fi

    rm -f "$SCAN_PID_FILE"
    notify "Scan gestoppt"
}

cleanup_scan_pid() {
    if [ -f "$SCAN_PID_FILE" ] && ! kill -0 "$(cat "$SCAN_PID_FILE")" 2>/dev/null; then
        rm -f "$SCAN_PID_FILE"
    fi
}

device_name_from_mac() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/Name: /{print $2; exit}'
}

device_connected() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"
}

device_paired() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"
}

device_trusted() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Trusted: yes"
}

build_device_list() {
    local seen=""
    local output=""
    local mac name prefix line

    while IFS= read -r line; do
        mac="$(awk '{print $2}' <<< "$line")"
        name="$(cut -d ' ' -f 3- <<< "$line")"

        [ -z "$mac" ] && continue
        [ -z "$name" ] && name="$mac"

        if grep -q "$mac" <<< "$seen"; then
            continue
        fi
        seen="${seen}${mac}"$'\n'

        prefix=""
        if device_connected "$mac"; then
            prefix="󰂱 [connected]"
        elif device_paired "$mac"; then
            prefix="󰂯 [paired]"
        else
            prefix="󰂲 [found]"
        fi

        output="${output}${prefix} ${name} (${mac})"$'\n'
    done < <(bluetoothctl devices)

    printf "%s" "$output"
}

main_menu() {
    local power_line scan_line devices menu choice

    if bt_powered; then
        power_line="󰂯  Bluetooth: ON"
    else
        power_line="󰂲  Bluetooth: OFF"
    fi

    if scan_running; then
        scan_line="󰑐  Scan stoppen"
    else
        scan_line="󰐕  Scan starten"
    fi

    devices="$(build_device_list)"

    menu="$power_line"$'\n'
    menu+="$scan_line"$'\n'
    menu+="────────────────"$'\n'
    menu+="$devices"

    choice="$(printf "%s" "$menu" | sed '/^$/d' | fuzzel --dmenu -p "$FUZZEL_PROMPT")"
    [ -z "${choice:-}" ] && exit 0

    case "$choice" in
        "󰂯  Bluetooth: ON")
            bluetoothctl power off >/dev/null && notify "Bluetooth ausgeschaltet"
            ;;
        "󰂲  Bluetooth: OFF")
            bluetoothctl power on >/dev/null && notify "Bluetooth eingeschaltet"
            ;;
        "󰐕  Scan starten")
            bluetoothctl power on >/dev/null 2>&1 || true
            start_scan
            ;;
        "󰑐  Scan stoppen")
            stop_scan
            ;;
        *)
            device_submenu "$choice"
            ;;
    esac
}

extract_mac() {
    sed -n 's/.*(\(.*\)).*/\1/p' <<< "$1"
}

device_submenu() {
    local entry="$1"
    local mac name connected paired trusted menu choice

    mac="$(extract_mac "$entry")"
    [ -z "$mac" ] && return

    name="$(device_name_from_mac "$mac")"
    [ -z "$name" ] && name="$mac"

    connected="no"
    paired="no"
    trusted="no"

    device_connected "$mac" && connected="yes"
    device_paired "$mac" && paired="yes"
    device_trusted "$mac" && trusted="yes"

    menu="󰉼  $name"$'\n'
    menu+="󰛳  MAC: $mac"$'\n'
    menu+="󰂱  Connected: $connected"$'\n'
    menu+="󰂯  Paired: $paired"$'\n'
    menu+="󰣾  Trusted: $trusted"$'\n'
    menu+="────────────────"$'\n'

    if [ "$connected" = "yes" ]; then
        menu+="󰍃  Trennen"$'\n'
    else
        menu+="󰂄  Verbinden"$'\n'
    fi

    if [ "$paired" = "no" ]; then
        menu+="󰂿  Pairen"$'\n'
    fi

    if [ "$trusted" = "no" ]; then
        menu+="󰣾  Trusten"$'\n'
    else
        menu+="󰤂  Untrust"$'\n'
    fi

    menu+="󰆴  Entfernen"$'\n'
    menu+="󰁍  Zurück"

    choice="$(printf "%s" "$menu" | fuzzel --dmenu -p "$name")"
    [ -z "${choice:-}" ] && return

    case "$choice" in
        "󰂄  Verbinden")
            bluetoothctl connect "$mac" >/dev/null && notify "Verbunden mit $name" || notify "Verbinden fehlgeschlagen: $name"
            ;;
        "󰍃  Trennen")
            bluetoothctl disconnect "$mac" >/dev/null && notify "Getrennt von $name" || notify "Trennen fehlgeschlagen: $name"
            ;;
        "󰂿  Pairen")
            bluetoothctl pair "$mac" >/dev/null && notify "Gepairt: $name" || notify "Pairing fehlgeschlagen: $name"
            ;;
        "󰣾  Trusten")
            bluetoothctl trust "$mac" >/dev/null && notify "Trusted: $name" || notify "Trust fehlgeschlagen: $name"
            ;;
        "󰤂  Untrust")
            bluetoothctl untrust "$mac" >/dev/null && notify "Untrusted: $name" || notify "Untrust fehlgeschlagen: $name"
            ;;
        "󰆴  Entfernen")
            bluetoothctl remove "$mac" >/dev/null && notify "Entfernt: $name" || notify "Entfernen fehlgeschlagen: $name"
            ;;
        *)
            return
            ;;
    esac
}

cleanup_scan_pid

while true; do
    main_menu
done
