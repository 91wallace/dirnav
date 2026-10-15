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

if [ -f "/etc/profile.d/dirnav.sh" ]; then
    $SUDO rm -f "/etc/profile.d/dirnav.sh"
    echo -e "${GREEN}✓${NC} Removido /etc/profile.d/dirnav.sh"
fi

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
        if grep -q "command dirnav" "$RC"; then
            sed -i '/# Dirnav shell integration/,/alias dir=cc/d' "$RC"
            sed -i '/function cc() {/,/alias dir=cc/d' "$RC"
            sed -i '/alias gg=/d' "$RC"
            sed -i '/alias cc=/d' "$RC"
            sed -i '/alias dir=/d' "$RC"
            echo -e "${GREEN}✓${NC} Integração removida de $RC"
        fi
    fi
done

echo -e "${GREEN}Desinstalação concluída!${NC}"
