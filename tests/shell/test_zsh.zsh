#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIRNAV_SH="$PROJECT_ROOT/dirnav.sh"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dirnav-zsh-test.XXXXXX")"
MOCK_BIN="$TEST_DIR/mock-bin"
TARGET_MOCK_DIR="$TEST_DIR/Pasta com espaço & Unicode ç"
ORIG_PWD="$PWD"
mkdir -p "$MOCK_BIN" "$TARGET_MOCK_DIR"

cleanup() {
    cd "$ORIG_PWD" || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT HUP INT TERM

cat > "$MOCK_BIN/dirnav" <<'EOF'
#!/usr/bin/env bash
cwd_file=''
for arg in "$@"; do
    case "$arg" in --cwd-file=*) cwd_file="${arg#*=}" ;; esac
done
if [[ "${MOCK_CANCEL:-0}" != 1 ]]; then
    printf '%s' "$TARGET_MOCK_DIR" > "$cwd_file"
fi
exit "${MOCK_EXIT_CODE:-0}"
EOF
chmod +x "$MOCK_BIN/dirnav"
export PATH="$MOCK_BIN:$PATH"
export TARGET_MOCK_DIR
source "$DIRNAV_SH"

dn
[[ "$PWD" == "$TARGET_MOCK_DIR" ]] || { print -u2 '[FAIL] Zsh não mudou para o destino'; exit 1; }
print '[PASS] seleção alterou o diretório Zsh para o destino especial'

cd "$TEST_DIR"
export MOCK_CANCEL=1
dn
[[ "$PWD" == "$TEST_DIR" ]] || { print -u2 '[FAIL] cancelamento alterou PWD'; exit 1; }
unset MOCK_CANCEL
print '[PASS] cancelamento preservou PWD'

export MOCK_EXIT_CODE=7
if dn; then
    print -u2 '[FAIL] função ocultou erro do executável'
    exit 1
else
    status=$?
fi
[[ "$status" -eq 7 && "$PWD" == "$TEST_DIR" ]] || { print -u2 '[FAIL] status/ PWD incorreto após erro'; exit 1; }
print '[PASS] erro propagou status e preservou PWD'
print '==> Todos os testes Zsh passaram!'
