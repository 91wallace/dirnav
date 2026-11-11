# Dirnav shell integration
function dn() {
    local tmp
    tmp="$(mktemp -t "dirnav-cwd.XXXXXX")"
    local dirnav_status=0
    command dirnav --cwd-file="$tmp" "$@" || dirnav_status=$?
    local cd_status=0
    if [ "$dirnav_status" -eq 0 ] && [ -s "$tmp" ]; then
        local target
        target="$(cat "$tmp")"
        if [ -n "$target" ] && [ -d "$target" ]; then
            builtin cd -- "$target" || cd_status=$?
        fi
    fi
    rm -f "$tmp" || true
    if [ "$dirnav_status" -ne 0 ]; then
        return "$dirnav_status"
    fi
    return "$cd_status"
}
alias dirnav=dn
if ! command -v cc >/dev/null 2>&1 || [ "$(type -t cc 2>/dev/null)" = "alias" ]; then
    alias cc=dn
fi
