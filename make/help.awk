# Reads the `## ` lines right above each target: the first is its summary, the rest its details.
/^## / { commentLines[++commentLineCount] = substr($0, 4); next }
/^[a-zA-Z0-9][a-zA-Z0-9_-]*:/ && commentLineCount {
    command = $0
    sub(/:.*/, "", command)
    commands[++commandCount] = command
    summaries[command] = commentLines[1]
    for (line = 2; line <= commentLineCount; line++) {
        details[command] = details[command] "\n  " commentLines[line]
    }
}
{ commentLineCount = 0 }
END {
    if (topic == "") {
        print "Commands (make help <command> shows its arguments):"
        for (commandNumber = 1; commandNumber <= commandCount; commandNumber++) {
            printf "  %-22s %s\n", commands[commandNumber], summaries[commands[commandNumber]]
        }
    } else if (topic in summaries) {
        printf "make %s\n  %s%s\n", topic, summaries[topic], topic in details ? details[topic] : "\n  Takes no arguments."
    } else {
        printf "No command named %s; make help lists them.\n", topic > "/dev/stderr"
        exit 1
    }
}
