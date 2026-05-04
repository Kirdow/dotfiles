#!/bin/bash
# Wrapper for i3status that fixes memory "used" to exclude buff/cache
# Used = MemTotal - MemAvailable (not MemTotal - MemFree)

kb_layout() {
    LG=$(setxkbmap -query | awk '/layout/{print $2}')
    VR=$(setxkbmap -query | awk '/variant/{print $2}')

    text="$LG"

    if [ ! -z "$VR" ]; then
        text="$text $VR"
    fi

    if [ "$text"="se" ] || [ -z "$text" ]; then
        echo ""
        exit 0
    fi

    dat="{ \"full_text\": \"$text\", \"color\":\"#AAEEFF\" }"

    echo "$dat"
}

fix_mem() {
    read -r total avail < <(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo)

    used_gib=$(awk "BEGIN{printf \"%.1f GiB\", ($total - $avail) / 1048576}")
    avail_gib=$(awk "BEGIN{printf \"%.1f GiB\", $avail / 1048576}")

    sed "s/\"name\":\"memory\",\"markup\":\"none\",\"full_text\":\"[^\"]*\"/\"name\":\"memory\",\"markup\":\"none\",\"full_text\":\"$used_gib | $avail_gib\"/"
}

next_entry() {
    append="$2"
    text="$1"
    if [ -z "$append" ]; then
        echo "$text"
        exit 0
    fi

    echo "$text$append,"
}

i3status -c ~/.config/i3status/config | while IFS= read -r line; do
    # Pass header lines through unchanged
    if [[ "$line" == '{"version"'* ]] || [[ "$line" == '[' ]]; then
        echo "$line"
        continue
    fi

    read -r total avail < <(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo)
    used_gib=$(awk "BEGIN{printf \"%.1f GiB\", ($total - $avail) / 1048576}")
    avail_gib=$(awk "BEGIN{printf \"%.1f GiB\", $avail / 1048576}")

    target=""
    target="$(next_entry "$target" "$(kb_layout)")"

    if [ -z "$target" ]; then
        echo "$line" | fix_mem
    else
        append="[$target"
        echo "${line/\[/$append}" | fix_mem
    fi
done
