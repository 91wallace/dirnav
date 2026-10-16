#!/usr/bin/env bash
set -e

BIN_PATH="/usr/local/bin/dirnav"
GREEN='\033[0;32m'
BLUE='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}==> Desinstalando dirnav do Linux/macOS...${NC}"

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

if [ -f "$BIN_PATH" ]; then
    $SUDO rm -f "$BIN_PATH"
    echo -e "${GREEN}[✓] Removido executavel: $BIN_PATH${NC}"
fi

if [ -f "/etc/profile.d/dirnav.sh" ]; then
    $SUDO rm -f "/etc/profile.d/dirnav.sh"
    echo -e "${GREEN}[✓] Removido /etc/profile.d/dirnav.sh${NC}"
fi

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
        if grep -q "command dirnav" "$RC" || grep -q "# Dirnav shell integration" "$RC"; then
            if command -v python3 >/dev/null 2>&1; then
                python3 - "$RC" << 'EOF'
import re, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()
content = re.sub(r'\n?# Dirnav shell integration\s+function cc\(\)\s*\{.*?\n\}(?:\s*alias dir=cc)?\n?', '\n', content, flags=re.DOTALL)
content = re.sub(r'\n?function cc\(\)\s*\{[^\}]*command dirnav[^\}]*\}(?:\s*alias dir=cc)?\n?', '\n', content, flags=re.DOTALL)
content = re.sub(r'^\s*alias (?:gg|cc|dir)=.*\n?', '', content, flags=re.MULTILINE)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content.strip() + '\n' if content.strip() else '')
EOF
            else
                sed -i '/# Dirnav shell integration/,/^}/d' "$RC"
                sed -i '/function cc() {/,/^}/d' "$RC"
                sed -i '/alias gg=/d' "$RC"
                sed -i '/alias cc=/d' "$RC"
                sed -i '/alias dir=/d' "$RC"
            fi
            echo -e "${GREEN}[✓] Integracao removida de $RC${NC}"
        fi
    fi
done

echo ""
echo -e "${GREEN}Desinstalacao concluida!${NC}"
