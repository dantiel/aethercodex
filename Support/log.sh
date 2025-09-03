cd Support
tail -n 500 -f ../.tm-ai/limen.log | awk '
BEGIN {
    # ANSI reset
    reset = "\033[0m"

    # A pleasant, readable palette (bright + regular). Add/remove as you wish.
    # Avoid pure black (30) because it can be invisible on dark terminals.
    colors_count = 0
    pal[++colors_count] = "\033[1;31m"  # bright red
    pal[++colors_count] = "\033[1;32m"  # bright green
    pal[++colors_count] = "\033[1;33m"  # bright yellow
    pal[++colors_count] = "\033[1;34m"  # bright blue
    pal[++colors_count] = "\033[1;35m"  # bright magenta
    pal[++colors_count] = "\033[1;36m"  # bright cyan
    pal[++colors_count] = "\033[91m"    # light red
    pal[++colors_count] = "\033[92m"    # light green
    pal[++colors_count] = "\033[94m"    # light blue
    pal[++colors_count] = "\033[95m"    # light magenta
    pal[++colors_count] = "\033[96m"    # light cyan
    pal[++colors_count] = "\033[33m"    # yellow
    pal[++colors_count] = "\033[36m"    # cyan
    pal[++colors_count] = "\033[35m"    # magenta
}

# --- helpers ---------------------------------------------------------------

function tag_hash(s,   i,c,sum,alpha) {
    # Simple, portable hash: sum of alphabet indices + digits
    # Avoids non-POSIX ord(); stable across awks.
    s = tolower(s)
    alpha = "abcdefghijklmnopqrstuvwxyz"
    sum = 0
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c >= "0" && c <= "9") {
            sum += c + 0
        } else {
            sum += index(alpha, c)
        }
    }
    # jitter for longer names
    sum += length(s) * 7
    return sum
}

function color_for_tag(tag,   h,idx) {
    h = tag_hash(tag)
    idx = (h % colors_count) + 1
    return pal[idx]
}

function trim_leading_junk(s) {
    # remove leading whitespace, colons, and dashes after the tag train
    sub(/^[[:space:]:-]+/, "", s)
    return s
}

# --- main ------------------------------------------------------------------

{
    line = $0
    ntags = 0

    # Collect all leading [..] tags in order
    while (match(line, /^\[[^]]+\]/)) {
        tag = substr(line, RSTART + 1, RLENGTH - 2)  # strip [ ]
        ntags++
        tags[ntags] = tag
        # consume this tag and continue
        line = substr(line, RSTART + RLENGTH)
        # also trim a possible immediate ":" after a tag block
        sub(/^:/, "", line)
    }

    # Remaining is the message (possibly empty)
    msg = trim_leading_junk(line)

    if (ntags > 0) {
        out = ""
        for (i = 1; i <= ntags; i++) {
            col = color_for_tag(tags[i])
            out = out col "[" tags[i] "]" reset
        }
        if (msg != "") {
            print out ": " msg
        } else {
            print out
        }
    } else {
        # No bracketed tags at the start—print as-is
        print $0
    }
}'



