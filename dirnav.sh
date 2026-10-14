# Dirnav shell integration
function dir() {
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

# Atalho alternativo cc (ideal para PowerShell/Windows/Linux) e compatibilidade gg
alias cc=dir
alias gg=dir
