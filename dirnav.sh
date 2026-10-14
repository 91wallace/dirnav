# Dirnav shell integration
function cc() {
    local tmp
    tmp="$(mktemp -t "dirnav-cwd.XXXXXX")"
    command dirnav "$@" --cwd-file="$tmp"
    if [ -s "$tmp" ]; then
        local target
        target="$(cat "$tmp")"
        if [ -n "$target" ] && [ -d "$target" ]; then
            builtin cd -- "$target"
        fi
    fi
    rm -f "$tmp"
}

# Aliases opcionais
alias dir=cc
alias gg=cc
