#!/bin/bash

DEV="sda"

util=$(iostat -dx 1 2 | awk -v dev="$DEV" '$1==dev {print $NF}' | tail -1)

printf "HDD %3.0f%%\n" "$util"

