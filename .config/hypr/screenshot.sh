#!/usr/bin/env bash

set -u

DIR="$HOME/Pictures"
mkdir -p "$DIR"

FILE="$DIR/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
TMPFILE="$(mktemp --suffix=.png)"

GEOM="$(slurp 2>/dev/null)"

[ -z "${GEOM:-}" ] && exit 0

if grim -g "$GEOM" "$TMPFILE"; then
    cp "$TMPFILE" "$FILE"
    wl-copy --type image/png <"$TMPFILE"
fi

rm -f "$TMPFILE"
