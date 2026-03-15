#!/bin/bash

DEV="sda"

read r1 w1 < <(awk -v dev="$DEV" '$3==dev {print $6, $10}' /proc/diskstats)
sleep 1
read r2 w2 < <(awk -v dev="$DEV" '$3==dev {print $6, $10}' /proc/diskstats)

r=$(( (r2 - r1) / 2 ))
w=$(( (w2 - w1) / 2 ))

echo "${r}R ${w}W"
