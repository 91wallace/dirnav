#!/usr/bin/env bash
set -e

REPO_RAW_URL="https://raw.githubusercontent.com/91wallace/dirnav/main"
BIN_DIR="/usr/local/bin"

# Cor para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==>${NC} Instalando dirnav..."

# Detecta se precisa de sudo para instalar em /usr/local/bin
SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

# 1. Instala o executável dirnav
if [ -f "./dirnav" ]; then
    $SUDO cp "./dirnav" "$BIN_DIR/dirnav"
else
    echo "Baixando dirnav de $REPO_RAW_URL/dirnav..."
    $SUDO curl -fsSL "$REPO_RAW_URL/dirnav" -o "$BIN_DIR/dirnav"
fi

$SUDO chmod +x "$BIN_DIR/dirnav"
echo -e "${GREEN}✓${NC} Executável instalado em $BIN_DIR/dirnav"

# 2. Configura a integração com o shell
INTEGRATION_BLOCK='
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
alias dir=cc
alias gg=cc
'

CONFIGURED=0
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
        if ! grep -q "command dirnav" "$RC"; then
            echo "$INTEGRATION_BLOCK" >> "$RC"
            echo -e "${GREEN}✓${NC} Integração adicionada a $RC"
            CONFIGURED=1
        else
            echo -e "${BLUE}i${NC} Integração já presente em $RC"
            CONFIGURED=1
        fi
    fi
done

if [ "$CONFIGURED" -eq 0 ]; then
    # Se nenhum rc encontrado, adiciona ao .bashrc por padrão
    echo "$INTEGRATION_BLOCK" >> "$HOME/.bashrc"
    echo -e "${GREEN}✓${NC} Integração adicionada a $HOME/.bashrc"
fi

echo ""
echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
echo "Para começar a usar na sessão atual, execute:"
echo -e "  ${BLUE}source ~/.bashrc${NC}  (ou abra um novo terminal)"
echo ""
echo "Comando principal: cc"
