#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dirnav-installer-test.XXXXXX")"
TEST_HOME="$TEST_ROOT/home"
MOCK_BIN="$TEST_ROOT/mock-bin"
mkdir -p "$TEST_HOME" "$MOCK_BIN"
cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

if ! python3 --version 2>&1 | grep -q '^Python 3'; then
    command -v py >/dev/null 2>&1 || { echo '[BLOCKED] Python 3/py.exe indisponível'; exit 77; }
    cat > "$MOCK_BIN/python3" <<'EOF'
#!/usr/bin/env bash
exec py -3 "$@"
EOF
    chmod +x "$MOCK_BIN/python3"
fi

export HOME="$TEST_HOME"
export PATH="$MOCK_BIN:$TEST_HOME/.local/bin:$PATH"
printf '%s\n' '# user-owned line' "alias keepme='printf keep'" > "$HOME/.bashrc"

if bash "$PROJECT_ROOT/install.sh" --shortcut='bad;shortcut' --non-interactive >/dev/null 2>&1; then
    echo '[FAIL] instalador aceitou atalho inválido'; exit 1
fi
[[ ! -e "$HOME/.local/bin/dirnav" ]] && grep -Fxq '# user-owned line' "$HOME/.bashrc" || { echo '[FAIL] validação inválida deixou artefato ou alterou perfil'; exit 1; }

bash "$PROJECT_ROOT/install.sh" --shortcut=dn --non-interactive
TARGET="$HOME/.local/bin/dirnav"
[[ -f "$TARGET" ]] || { echo '[FAIL] binário não instalado no HOME isolado'; exit 1; }
grep -Fxq '# DIRNAV_MANAGED_INSTALL' "$TARGET" || { echo '[FAIL] marcador de propriedade ausente'; exit 1; }
[[ -f "$HOME/.local/bin/dirnav_operations.py" ]] || { echo '[FAIL] módulo de operações não instalado'; exit 1; }
grep -Fxq '# DIRNAV_MANAGED_INSTALL' "$HOME/.local/bin/dirnav_operations.py" || { echo '[FAIL] marcador do módulo ausente'; exit 1; }
[[ "$(grep -Fc '# Dirnav shell integration' "$HOME/.bashrc")" -eq 1 ]] || { echo '[FAIL] bloco de perfil duplicado'; exit 1; }
grep -Fq "alias keepme='printf keep'" "$HOME/.bashrc" || { echo '[FAIL] linha não relacionada foi alterada'; exit 1; }
bash -n "$HOME/.bashrc"

FILE_TEST_HOME="$TEST_HOME/file-operations"
mkdir -p "$FILE_TEST_HOME/destination & unicode-ç"
printf '%s' 'bash file operation' > "$FILE_TEST_HOME/source & ç.txt"
(
    cd "$FILE_TEST_HOME"
    source "$HOME/.bashrc"
    export DIRNAV_TEST_KEYS='F7,s,o,u,r,c,e,F5,RIGHT,ENTER,ENTER,ESC'
    dn
    [[ "$PWD" == "$FILE_TEST_HOME" ]] || { echo '[FAIL] operação de arquivo alterou o CWD da sessão Bash'; exit 1; }
    [[ "$(cat 'destination & unicode-ç/source & ç.txt')" == 'bash file operation' ]] || { echo '[FAIL] operação F5 Bash não copiou o arquivo'; exit 1; }
    [[ "$(cat 'source & ç.txt')" == 'bash file operation' ]] || { echo '[FAIL] operação F5 Bash alterou a origem'; exit 1; }
)
unset DIRNAV_TEST_KEYS

bash "$PROJECT_ROOT/install.sh" --shortcut=dn --non-interactive
[[ "$(grep -Fc '# Dirnav shell integration' "$HOME/.bashrc")" -eq 1 ]] || { echo '[FAIL] reinstalação duplicou integração'; exit 1; }

mv "$TARGET" "$TARGET.real"
cat > "$TARGET" <<'EOF'
#!/usr/bin/env bash
cwd_file=''
for arg in "$@"; do
    case "$arg" in --cwd-file=*) cwd_file="${arg#*=}" ;; esac
done
if [[ "${MOCK_CANCEL:-0}" == 1 ]]; then exit 0; fi
printf '%s' "$TARGET_MOCK_DIR" > "$cwd_file"
exit "${MOCK_EXIT_CODE:-0}"
EOF
chmod 755 "$TARGET"
TARGET_MOCK_DIR="$TEST_HOME/selected & unicode-ç"
mkdir -p "$TARGET_MOCK_DIR"
export TARGET_MOCK_DIR

(
    cd "$TEST_HOME"
    source "$HOME/.bashrc"
    dn
    [[ "$PWD" == "$TARGET_MOCK_DIR" ]] || { echo '[FAIL] função não aplicou diretório selecionado'; exit 1; }
    cd "$TEST_HOME"
    export MOCK_CANCEL=1
    dn
    [[ "$PWD" == "$TEST_HOME" ]] || { echo '[FAIL] cancelamento alterou diretório'; exit 1; }
    unset MOCK_CANCEL
    export MOCK_EXIT_CODE=7
    if dn; then echo '[FAIL] erro do mock foi ocultado'; exit 1; else status=$?; fi
    [[ "$status" -eq 7 && "$PWD" == "$TEST_HOME" ]] || { echo '[FAIL] erro alterou diretório ou status'; exit 1; }
)

rm -f "$TARGET"
mv "$TARGET.real" "$TARGET"
bash "$PROJECT_ROOT/uninstall.sh"
[[ ! -e "$TARGET" ]] || { echo '[FAIL] desinstalador não removeu binário marcado'; exit 1; }
[[ ! -e "$HOME/.local/bin/dirnav_operations.py" ]] || { echo '[FAIL] desinstalador não removeu módulo marcado'; exit 1; }
! grep -Fq '# Dirnav shell integration' "$HOME/.bashrc" || { echo '[FAIL] bloco dirnav permaneceu no perfil'; exit 1; }
grep -Fq '# user-owned line' "$HOME/.bashrc" || { echo '[FAIL] desinstalador removeu linha alheia'; exit 1; }
grep -Fq "alias keepme='printf keep'" "$HOME/.bashrc" || { echo '[FAIL] desinstalador removeu alias alheio'; exit 1; }

printf '%s\n' 'unowned binary must remain' > "$TARGET"
if bash "$PROJECT_ROOT/install.sh" --shortcut=dn --non-interactive >/dev/null 2>&1; then
    echo '[FAIL] instalador sobrescreveu binário não marcado'; exit 1
fi
grep -Fxq 'unowned binary must remain' "$TARGET" || { echo '[FAIL] binário não marcado foi alterado'; exit 1; }

ZSH_HOME="$TEST_ROOT/zsh-home"
mkdir -p "$ZSH_HOME"
HOME="$ZSH_HOME" SHELL=/usr/bin/zsh bash "$PROJECT_ROOT/install.sh" --non-interactive >/dev/null
[[ -f "$ZSH_HOME/.zshrc" && ! -e "$ZSH_HOME/.bashrc" ]] || { echo '[FAIL] instalação Zsh sem perfil não criou .zshrc'; exit 1; }
HOME="$ZSH_HOME" bash "$PROJECT_ROOT/uninstall.sh" >/dev/null
[[ ! -e "$ZSH_HOME/.local/bin/dirnav" ]] || { echo '[FAIL] instalação isolada Zsh não foi removida'; exit 1; }
[[ ! -e "$ZSH_HOME/.local/bin/dirnav_operations.py" ]] || { echo '[FAIL] instalação isolada Zsh deixou o módulo'; exit 1; }

if grep -Eq '/usr/local/bin|/etc/profile\.d|sudo ' "$PROJECT_ROOT/install.sh" "$PROJECT_ROOT/uninstall.sh"; then
    echo '[FAIL] script contém operação global inesperada'; exit 1
fi

echo '[PASS] instalação per-user, idempotência, seleção, cancelamento, erros, preservação e desinstalação isolada'
