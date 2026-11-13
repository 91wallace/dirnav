#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
    printf 'Uso: %s\n' "$0"
    printf 'Remove somente a instalação marcada do usuário atual em ~/.local/bin.\n'
    exit 0
fi
[[ $# -eq 0 ]] || { printf '[ERRO] Argumentos não são aceitos: %s\n' "$*" >&2; exit 2; }
[[ "$(id -u)" != 0 ]] || { printf '[ERRO] Não execute como root/sudo.\n' >&2; exit 1; }

BIN_PATH="${HOME:?HOME is required}/.local/bin/dirnav"
OPERATIONS_PATH="$HOME/.local/bin/dirnav_operations.py"
STATUS=0
if [[ -L "$HOME/.local" || -L "$HOME/.local/bin" ]]; then
    printf '[AVISO] Diretório de instalação contém symlink; binário preservado: %s\n' "$BIN_PATH" >&2
    STATUS=1
elif [[ -e "$BIN_PATH" || -L "$BIN_PATH" ]]; then
    if [[ -f "$BIN_PATH" && ! -L "$BIN_PATH" ]] && grep -Fxq '# DIRNAV_MANAGED_INSTALL' "$BIN_PATH"; then
        rm -f "$BIN_PATH"
        printf '[OK] Removido binário dirnav gerenciado: %s\n' "$BIN_PATH"
    else
        printf '[AVISO] Binário sem marcador dirnav preservado: %s\n' "$BIN_PATH" >&2
        STATUS=1
    fi
fi

if [[ -L "$HOME/.local" || -L "$HOME/.local/bin" ]]; then
    printf '[AVISO] Diretório de instalação contém symlink; módulo preservado: %s\n' "$OPERATIONS_PATH" >&2
    STATUS=1
elif [[ -e "$OPERATIONS_PATH" || -L "$OPERATIONS_PATH" ]]; then
    if [[ -f "$OPERATIONS_PATH" && ! -L "$OPERATIONS_PATH" ]] && grep -Fxq '# DIRNAV_MANAGED_INSTALL' "$OPERATIONS_PATH"; then
        rm -f "$OPERATIONS_PATH"
        printf '[OK] Removido módulo dirnav gerenciado: %s\n' "$OPERATIONS_PATH"
    else
        printf '[AVISO] Módulo sem marcador dirnav preservado: %s\n' "$OPERATIONS_PATH" >&2
        STATUS=1
    fi
fi

for RC in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    [[ -f "$RC" ]] || continue
    if [[ -L "$RC" ]]; then
        printf '[AVISO] Perfil symlink preservado: %s\n' "$RC" >&2
        STATUS=1
        continue
    fi
    if ! grep -Fq '# Dirnav shell integration' "$RC" && ! grep -Fq '# END Dirnav shell integration' "$RC"; then
        continue
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        printf '[ERRO] Python 3 é necessário para remover com segurança a integração de %s. Arquivo preservado.\n' "$RC" >&2
        STATUS=1
        continue
    fi
    if python3 - "$RC" <<'PY'
import os, stat, sys, tempfile
path = sys.argv[1]
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
        raise SystemExit("perfil contém bloco dirnav incompleto; arquivo preservado")
    last += len(end)
    if content[last:last + 2] == "\r\n":
        last += 2
    elif content[last:last + 1] == "\n":
        last += 1
    content = content[:first] + content[last:]
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
    then
        printf '[OK] Removida integração delimitada de %s\n' "$RC"
    else
        printf '[ERRO] Não foi possível validar/remover a integração de %s; arquivo preservado.\n' "$RC" >&2
        STATUS=1
    fi
done

exit "$STATUS"
