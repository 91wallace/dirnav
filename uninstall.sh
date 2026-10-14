#!/usr/bin/env bash
set -e

BIN_PATH="/usr/local/bin/dirnav"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==>${NC} Desinstalando dirnav..."

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

if [ -f "$BIN_PATH" ]; then
    $SUDO rm -f "$BIN_PATH"
    echo -e "${GREEN}✓${NC} Removido $BIN_PATH"
fi

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
        if grep -q "command dirnav" "$RC"; then
            # Remove o bloco de integração
            sed -i '/# Dirnav shell integration/,/alias gg=dir/d' "$RC"
            sed -i '/alias cc=dir/d' "$RC"
            echo -e "${GREEN}✓${NC} Integração removida de $RC"
        fi
    fi
done

echo -e "${GREEN}Desinstalação concluída!${NC}"
