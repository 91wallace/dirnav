# Dirnav shell integration
function dn() {
    local tmp
    tmp="$(mktemp -t "dirnav-cwd.XXXXXX")"
    command dirnav --cwd-file="$tmp" "$@"
    if [ -s "$tmp" ]; then
        local target
        target="$(cat "$tmp")"
        if [ -n "$target" ] && [ -d "$target" ]; then
            builtin cd -- "$target"
        fi
    fi
    rm -f "$tmp"
}
alias dirnav=dn
if ! command -v cc >/dev/null 2>&1 || [ "$(type -t cc 2>/dev/null)" = "alias" ]; then
    alias cc=dn
fi
