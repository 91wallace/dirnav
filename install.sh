#!/usr/bin/env bash
set -e

REPO_RAW_URL="https://raw.githubusercontent.com/91wallace/dirnav/main"
BIN_DIR="/usr/local/bin"

# Cor para output
GREEN='\033[0;32m'
BLUE='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==> Instalando dirnav no Linux/macOS...${NC}"

# 1. Verifica Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}Erro: Python 3 nao foi encontrado no PATH. Por favor, instale o Python 3 antes de continuar.${NC}" >&2
    exit 1
fi

# Detecta se precisa de sudo para instalar em /usr/local/bin
SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

# 2. Cria diretorio de destino caso nao exista
if [ ! -d "$BIN_DIR" ]; then
    $SUDO mkdir -p "$BIN_DIR"
fi

# 3. Instala o executável dirnav (garantindo quebras de linha LF)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
if [ -f "$SCRIPT_DIR/dirnav" ]; then
    tr -d '\r' < "$SCRIPT_DIR/dirnav" | $SUDO tee "$BIN_DIR/dirnav" >/dev/null
elif [ -f "./dirnav" ]; then
    tr -d '\r' < "./dirnav" | $SUDO tee "$BIN_DIR/dirnav" >/dev/null
else
    echo -e "${GRAY}Baixando dirnav de $REPO_RAW_URL/dirnav...${NC}"
    curl -fsSL "$REPO_RAW_URL/dirnav" | tr -d '\r' | $SUDO tee "$BIN_DIR/dirnav" >/dev/null
fi

$SUDO chmod +x "$BIN_DIR/dirnav"
echo -e "${GREEN}[✓] Executavel instalado em: $BIN_DIR/dirnav${NC}"

# 4. Configura a integração com o shell
INTEGRATION_BLOCK='
# Dirnav shell integration
function cc() {
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
'

CONFIGURED=0
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
        if ! grep -q "function cc()" "$RC" && ! grep -q "command dirnav" "$RC"; then
            printf "%s\n" "$INTEGRATION_BLOCK" >> "$RC"
            echo -e "${GREEN}[✓] Integracao adicionada ao perfil do shell: $RC${NC}"
            CONFIGURED=1
        else
            echo -e "${GRAY}[i] Integracao ja presente no perfil do shell: $RC${NC}"
            CONFIGURED=1
        fi
    fi
done

if [ "$CONFIGURED" -eq 0 ]; then
    # Se nenhum rc encontrado, adiciona ao .bashrc por padrão
    printf "%s\n" "$INTEGRATION_BLOCK" >> "$HOME/.bashrc"
    echo -e "${GREEN}[✓] Integracao adicionada ao perfil do shell: $HOME/.bashrc${NC}"
fi

echo ""
echo -e "${GREEN}Instalacao concluida com sucesso!${NC}"
echo -e "${YELLOW}Para utilizar na sessao atual:${NC}"
echo -e "  ${BLUE}source ~/.bashrc${NC}"
echo -e "${YELLOW}Comando: cc${NC}"
