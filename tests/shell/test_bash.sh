#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIRNAV_SH="$PROJECT_ROOT/dirnav.sh"

echo "==> Executando testes de integracao Bash (dirnav.sh)"

# 1. Carrega dirnav.sh
source "$DIRNAV_SH"

# 2. Verifica funcao dn
if ! declare -f dn >/dev/null; then
    echo "[FAIL] Funcao 'dn' nao foi definida por dirnav.sh"
    exit 1
fi
echo "  [PASS] Funcao 'dn' definida com sucesso"

# 3. Testa mudanca de diretorio simulando o binario dirnav escrevendo no --cwd-file
TEST_DIR="$(mktemp -d -t "dirnav-bash-test.XXXXXX")"
SPECIAL_SUBDIR="$TEST_DIR/Pasta [2026]"
mkdir -p "$SPECIAL_SUBDIR"

ORIG_PWD="$PWD"
cleanup() {
    cd "$ORIG_PWD" || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Sobrescreve comando dirnav no PATH usando diretorio temporario de bin
MOCK_BIN="$TEST_DIR/mock_bin"
mkdir -p "$MOCK_BIN"
cat << 'EOF' > "$MOCK_BIN/dirnav"
#!/usr/bin/env bash
for arg in "$@"; do
    case "$arg" in
        --cwd-file=*)
            CWD_FILE="${arg#*=}"
            printf "%s" "$TARGET_MOCK_DIR" > "$CWD_FILE"
            ;;
    esac
done
EOF
chmod +x "$MOCK_BIN/dirnav"

export PATH="$MOCK_BIN:$PATH"
export TARGET_MOCK_DIR="$SPECIAL_SUBDIR"

dn

if [ "$PWD" != "$SPECIAL_SUBDIR" ]; then
    echo "[FAIL] Esperado PWD='$SPECIAL_SUBDIR', obtido '$PWD'"
    exit 1
fi
echo "  [PASS] Funcao 'dn' mudou com sucesso para diretorio com espacos e colchetes: $PWD"
echo "==> Todos os testes Bash passaram!"
