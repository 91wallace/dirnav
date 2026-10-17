#!/usr/bin/env bash
set -e

REPO_RAW_URL="https://raw.githubusercontent.com/91wallace/dirnav/main"
BIN_DIR="/usr/local/bin"

# Cores para output
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
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        # Se não tiver sudo, instala localmente no PATH do usuário
        BIN_DIR="$HOME/.local/bin"
    fi
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

# 4. Configura integração no sistema (/etc/profile.d para RHEL/Oracle/Debian/Ubuntu)
INTEGRATION_BLOCK='
# Dirnav shell integration
function dn() {
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
alias dirnav=dn
if ! command -v cc >/dev/null 2>&1 || [ "$(type -t cc 2>/dev/null)" = "alias" ]; then
    alias cc=dn
fi
'

if [ -d "/etc/profile.d" ]; then
    printf "%s\n" "$INTEGRATION_BLOCK" | $SUDO tee "/etc/profile.d/dirnav.sh" >/dev/null
    $SUDO chmod +x "/etc/profile.d/dirnav.sh" 2>/dev/null || true
    echo -e "${GREEN}[✓] Integracao global adicionada em: /etc/profile.d/dirnav.sh${NC}"
fi

# 5. Detecta o diretório home do usuário real (mesmo executando com sudo)
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    TARGET_HOME="$HOME"
fi

clean_and_add_rc() {
    local rc_file="$1"
    [ -f "$rc_file" ] || return 0

    # Remove integrações antigas (cc / dirnav antigos)
    if grep -q "command dirnav" "$rc_file" || grep -q "# Dirnav shell integration" "$rc_file"; then
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$rc_file" << 'EOF'
import re, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()
content = re.sub(r'\n?# Dirnav shell integration\s+function (?:cc|dn)\(\)\s*\{.*?\n\}(?:\s*alias (?:dirnav|dir)=.*)?\n?', '\n', content, flags=re.DOTALL)
content = re.sub(r'\n?function (?:cc|dn)\(\)\s*\{[^\}]*command dirnav[^\}]*\}(?:\s*alias (?:dirnav|dir)=.*)?\n?', '\n', content, flags=re.DOTALL)
content = re.sub(r'^\s*alias (?:gg|cc|dir)=.*\n?', '', content, flags=re.MULTILINE)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content.strip() + '\n' if content.strip() else '')
EOF
        fi
    fi

    printf "%s\n" "$INTEGRATION_BLOCK" >> "$rc_file"
    echo -e "${GREEN}[✓] Integracao adicionada ao perfil: $rc_file${NC}"
}

CONFIGURED=0
for RC in "$TARGET_HOME/.bashrc" "$TARGET_HOME/.zshrc" "$TARGET_HOME/.bash_profile"; do
    if [ -f "$RC" ]; then
        clean_and_add_rc "$RC"
        CONFIGURED=1
    fi
done

if [ "$CONFIGURED" -eq 0 ]; then
    clean_and_add_rc "$TARGET_HOME/.bashrc"
fi

echo ""
echo -e "${GREEN}Instalacao concluida com sucesso!${NC}"
echo -e "${YELLOW}Para utilizar na sessao atual:${NC}"
echo -e "  ${BLUE}source ~/.bashrc${NC}"
echo -e "${YELLOW}Comando:${NC} ${GREEN}dn${NC} (ou ${GREEN}dirnav${NC})"
