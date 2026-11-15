# Turns swift compiler diagnostics into GitHub workflow commands, so they show
# as annotations on the run and on the PR diff.
#
#   /path/File.swift:12:5: warning: message
#
# A diagnostic inside a macro expansion such as #expect is reported against the
# expansion, with the source location on the following note:
#
#   macro expansion #expect:1:22: warning: message
#   `- /path/File.swift:118:10: note: expanded code originates here
#
# Without that note, it is reported without a location. Diagnostics repeat,
# for example when a file is compiled twice or #expect reports one twice, so
# each message is reported once per line.
#
# GitHub shows at most 10 annotations of each type per step, so when `summary`
# names a file (GITHUB_STEP_SUMMARY), every diagnostic is also listed there.

function escape_data(s) {
    gsub(/%/, "%25", s); gsub(/\r/, "%0D", s); gsub(/\n/, "%0A", s)
    return s
}

function escape_property(s) {
    s = escape_data(s); gsub(/:/, "%3A", s); gsub(/,/, "%2C", s)
    return s
}

function escape_cell(s) {
    gsub(/\|/, "\\|", s)
    return s
}

function annotate(file, line, col, type, message,    key) {
    if (index(file, root) == 1) file = substr(file, length(root) + 1)
    key = file ":" line ":" type ":" message
    if (key in seen) return
    seen[key] = 1
    count[type]++
    list[++total] = sprintf("| %s | %s | %s |", type, (file == "" ? "" : "`" file ":" line "`"), escape_cell(message))
    if (file == "")
        printf "::%s::%s\n", type, escape_data(message)
    else
        printf "::%s file=%s,line=%s,col=%s::%s\n", type, escape_property(file), line, col, escape_data(message)
}

# location prefix "path:line:col: " followed by "warning: " or "error: "
function parse(text, out,    m) {
    if (!match(text, /:[0-9]+:[0-9]+: (warning|error|note): /)) return 0
    out["file"] = substr(text, 1, RSTART - 1)
    split(substr(text, RSTART + 1, RLENGTH - 3), m, ":")
    out["line"] = m[1]; out["col"] = m[2]; out["type"] = m[3]; sub(/^ /, "", out["type"])
    out["message"] = substr(text, RSTART + RLENGTH)
    return 1
}

{
    if (pending_type != "") {
        if (sub(/^`- /, "") && parse($0, d) && d["type"] == "note" && d["message"] == "expanded code originates here") {
            annotate(d["file"], d["line"], d["col"], pending_type, pending_message)
            pending_type = ""
            next
        }
        annotate("", "", "", pending_type, pending_message)
        pending_type = ""
    }
    if (/^macro expansion / && parse($0, d) && d["type"] != "note") {
        pending_type = d["type"]; pending_message = d["message"]
        next
    }
    if (/^\// && parse($0, d) && d["type"] != "note") {
        annotate(d["file"], d["line"], d["col"], d["type"], d["message"])
    }
}

END {
    printf "%d warning(s), %d error(s)\n", count["warning"], count["error"]
    if (summary == "" || total == 0) exit
    printf "### Build diagnostics\n\n%d warning(s), %d error(s)\n\n| | Location | Message |\n|---|---|---|\n", count["warning"], count["error"] >> summary
    for (i = 1; i <= total; i++) print list[i] >> summary
}
