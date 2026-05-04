#!/usr/bin/env bash

LG=$(setxkbmap -query | awk '/layout/{print $2}')

if [ -z "$LG" ] || [ "$LG"="ru" ]; then
    setxkbmap -layout se -model pc105 -variant "" -option ""
elif [ "$LG"="se" ]; then
    setxkbmap -layout ru -variant phonetic
fi
    
