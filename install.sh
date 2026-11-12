#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_URL="https://raw.githubusercontent.com/91wallace/dirnav/main"
BIN_DIR="${HOME:?HOME is required}/.local/bin"
USER_SHORTCUT=""
NON_INTERACTIVE=0

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

fail() { printf '%b\n' "${RED}[ERRO] $*${NC}" >&2; exit 1; }

while (($#)); do
    case "$1" in
        --shortcut=*|--alias=*) USER_SHORTCUT="${1#*=}"; shift ;;
        -s|-a|--shortcut|--alias)
            (($# >= 2)) || fail "Falta o valor de $1"
            USER_SHORTCUT="$2"; shift 2 ;;
        -y|--yes|--default|--non-interactive) NON_INTERACTIVE=1; shift ;;
        -h|--help)
            printf 'Uso: %s [--shortcut NOME] [--non-interactive]\n' "$0"
            printf 'Instala somente no usuário atual em ~/.local/bin.\n'
            exit 0 ;;
        *) fail "Argumento desconhecido: $1" ;;
    esac
done

if [[ "$(id -u)" == 0 ]]; then
    fail "Não execute como root/sudo. Este instalador altera somente o HOME do usuário atual."
fi
command -v python3 >/dev/null 2>&1 || fail "Python 3 não foi encontrado no PATH."
PYTHON_VERSION="$(python3 --version 2>&1)" || fail "python3 não inicia corretamente: $PYTHON_VERSION"
[[ "$PYTHON_VERSION" == Python\ 3.* ]] || fail "python3 não é uma instalação funcional do Python 3: $PYTHON_VERSION"

if [[ -z "$USER_SHORTCUT" && "$NON_INTERACTIVE" -eq 0 ]]; then
    if [[ -t 0 || -r /dev/tty ]]; then
        printf 'Atalho principal [dn]: '
        read -r USER_SHORTCUT < /dev/tty || USER_SHORTCUT=""
    fi
fi
USER_SHORTCUT="${USER_SHORTCUT:-dn}"
[[ "$USER_SHORTCUT" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] || fail "Nome de atalho inválido: $USER_SHORTCUT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$(mktemp "${TMPDIR:-/tmp}/dirnav-source.XXXXXX")"
STAGED_FILE=""
cleanup() {
    rm -f "$SOURCE_FILE"
    [[ -z "$STAGED_FILE" ]] || rm -f "$STAGED_FILE"
}
trap cleanup EXIT HUP INT TERM

if [[ -f "$SCRIPT_DIR/dirnav" ]]; then
    tr -d '\r' < "$SCRIPT_DIR/dirnav" > "$SOURCE_FILE"
else
    curl -fsSL "$REPO_RAW_URL/dirnav" | tr -d '\r' > "$SOURCE_FILE"
fi

IFS= read -r SHEBANG < "$SOURCE_FILE" || fail "Fonte dirnav vazia."
[[ "$SHEBANG" == '#!'* ]] || fail "A fonte dirnav não contém shebang válido."
[[ ! -L "$HOME/.local" && ! -L "$BIN_DIR" ]] || fail "Destino per-user passa por symlink; instalação cancelada."
mkdir -p "$BIN_DIR"
TARGET="$BIN_DIR/dirnav"
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    [[ -f "$TARGET" && ! -L "$TARGET" ]] || fail "Destino existente não é um arquivo regular: $TARGET"
    grep -Fxq '# DIRNAV_MANAGED_INSTALL' "$TARGET" || fail "Destino existente sem marcador dirnav; preservado: $TARGET"
fi

STAGED_FILE="$(mktemp "$BIN_DIR/.dirnav-stage.XXXXXX")"
{
    printf '%s\n# DIRNAV_MANAGED_INSTALL\n' "$SHEBANG"
    tail -n +2 "$SOURCE_FILE"
} > "$STAGED_FILE"
chmod 755 "$STAGED_FILE"
mv -f "$STAGED_FILE" "$TARGET"
STAGED_FILE=""

INTEGRATION_BLOCK="$(cat <<'EOF'
# Dirnav shell integration
function __DIRNAV_SHORTCUT__() {
    local tmp dirnav_status cd_status target
    tmp="$(mktemp "${TMPDIR:-/tmp}/dirnav-cwd.XXXXXX")" || return 1
    dirnav_status=0
    "$HOME/.local/bin/dirnav" --cwd-file="$tmp" "$@" || dirnav_status=$?
    cd_status=0
    if [[ "$dirnav_status" -eq 0 && -s "$tmp" ]]; then
        target=$(cat "$tmp")
        if [[ -n "$target" && -d "$target" ]]; then
            builtin cd -- "$target" || cd_status=$?
        fi
    fi
    rm -f "$tmp" || true
    if [[ "$dirnav_status" -ne 0 ]]; then return "$dirnav_status"; fi
    return "$cd_status"
}
EOF
)"
INTEGRATION_BLOCK="${INTEGRATION_BLOCK//__DIRNAV_SHORTCUT__/$USER_SHORTCUT}"
if [[ "$USER_SHORTCUT" != dirnav ]]; then
    INTEGRATION_BLOCK+=$'\nalias dirnav='"$USER_SHORTCUT"
fi
INTEGRATION_BLOCK+=$'\nif ! command -v cc >/dev/null 2>&1 || [[ $(type -t cc 2>/dev/null || true) == alias ]]; then alias cc='"$USER_SHORTCUT"'; fi'
INTEGRATION_BLOCK+=$'\n# END Dirnav shell integration'

TARGET_HOME="$HOME"
PROFILE_COUNT=0
for RC in "$TARGET_HOME/.bashrc" "$TARGET_HOME/.zshrc" "$TARGET_HOME/.bash_profile"; do
    [[ -f "$RC" ]] || continue
    [[ ! -L "$RC" ]] || fail "Perfil é symlink e foi preservado: $RC"
    python3 - "$RC" "$INTEGRATION_BLOCK" <<'PY'
import os, stat, sys, tempfile

path, block = sys.argv[1:]
if os.path.islink(path):
    raise SystemExit("perfil é symlink; arquivo preservado")
start = "# Dirnav shell integration"
end = "# END Dirnav shell integration"
with open(path, "r", encoding="utf-8", errors="surrogateescape", newline="") as stream:
    content = stream.read()
while start in content or end in content:
    first = content.find(start)
    last = content.find(end)
    if first < 0 or last < first:
        raise SystemExit("perfil contém bloco dirnav antigo/incompleto; arquivo preservado")
    last += len(end)
    if content[last:last + 2] == "\r\n":
        last += 2
    elif content[last:last + 1] == "\n":
        last += 1
    content = content[:first] + content[last:]
content = content.rstrip("\r\n")
content = (content + "\n\n" if content else "") + block + "\n"
mode = stat.S_IMODE(os.stat(path).st_mode)
fd, temporary = tempfile.mkstemp(prefix=".dirnav-profile-", dir=os.path.dirname(path))
try:
    with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape", newline="") as stream:
        stream.write(content)
    os.chmod(temporary, mode)
    os.replace(temporary, path)
except BaseException:
    try:
        os.unlink(temporary)
    except OSError:
        pass
    raise
PY
    ((PROFILE_COUNT+=1))
done

if ((PROFILE_COUNT == 0)); then
    if [[ "${SHELL##*/}" == zsh ]]; then
        RC="$TARGET_HOME/.zshrc"
    else
        RC="$TARGET_HOME/.bashrc"
    fi
    [[ ! -L "$RC" ]] || fail "Perfil é symlink e foi preservado: $RC"
    : >> "$RC"
    python3 - "$RC" "$INTEGRATION_BLOCK" <<'PY'
import os, stat, sys, tempfile
path, block = sys.argv[1:]
if os.path.islink(path):
    raise SystemExit("perfil é symlink; arquivo preservado")
with open(path, "r", encoding="utf-8", errors="surrogateescape", newline="") as stream:
    content = stream.read()
if "# Dirnav shell integration" in content or "# END Dirnav shell integration" in content:
    raise SystemExit("perfil contém integração antiga/incompleta; arquivo preservado")
content = (content.rstrip("\r\n") + "\n\n" if content.strip() else "") + block + "\n"
mode = stat.S_IMODE(os.stat(path).st_mode)
fd, temporary = tempfile.mkstemp(prefix=".dirnav-profile-", dir=os.path.dirname(path))
try:
    with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape", newline="") as stream:
        stream.write(content)
    os.chmod(temporary, mode)
    os.replace(temporary, path)
except BaseException:
    try:
        os.unlink(temporary)
    except OSError:
        pass
    raise
PY
fi

printf '%b\n' "${GREEN}[OK] dirnav instalado em $TARGET${NC}"
printf '%b\n' "${BLUE}Integração adicionada somente aos perfis do usuário atual.${NC}"
printf '%b\n' "${BLUE}Abra um novo Bash/Zsh ou carregue novamente o perfil para usar '$USER_SHORTCUT'.${NC}"
