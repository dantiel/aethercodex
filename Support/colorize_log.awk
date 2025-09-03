# Define ANSI color codes as variables
BEGIN {
    # Text styles
    reset = "\033[0m"
    bold = "\033[1m"

    # Foreground colors
    black = "\033[30m"
    red = "\033[31m"
    green = "\033[32m"
    yellow = "\033[33m"
    blue = "\033[34m"
    magenta = "\033[35m"
    cyan = "\033[36m"
    white = "\033[37m"
}

# Process each line of the log file
{
    # Use 'match()' with a regex to capture the parts of the log line
    # a[1] = Module, a[2] = Class, a[3] = Method
    if (match($0, /^\[([^\]]+)\]\[([^\]]+)\]\[([^\]]+)\]: (.*)$/, a)) {
        # Reconstruct the line with colors
        printf "%s[%s]%s%s[%s]%s%s[%s]%s:%s %s%s\n", \
               cyan, a[1], reset, \
               yellow, a[2], reset, \
               magenta, a[3], reset, \
               bold, a[4], reset
    } else {
        # If the line doesn't match the pattern, print it as is
        print
    }
}