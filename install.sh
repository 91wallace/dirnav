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
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}==> Instalador do dirnav (Linux/macOS)${NC}"

# 0. Leitura de argumentos opcionais (--shortcut=..., -s ..., -y, --default)
USER_SHORTCUT=""
NON_INTERACTIVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --shortcut=*|--alias=*)
            USER_SHORTCUT="${1#*=}"
            shift
            ;;
        -s|-a|--shortcut|--alias)
            USER_SHORTCUT="$2"
            shift 2
            ;;
        -y|--yes|--default|--non-interactive)
            NON_INTERACTIVE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

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
        BIN_DIR="$HOME/.local/bin"
    fi
fi

# 2. Cria diretorio de destino caso nao exista
if [ ! -d "$BIN_DIR" ]; then
    $SUDO mkdir -p "$BIN_DIR"
fi

# 3. Instala o executável dirnav
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

# 4. Escolha interativa do comando de atalho
TTY_IN=""
if [ -t 0 ]; then
    TTY_IN="/dev/stdin"
elif [ -r /dev/tty ]; then
    TTY_IN="/dev/tty"
fi

if [ -z "$USER_SHORTCUT" ] && [ "$NON_INTERACTIVE" -eq 0 ]; then
    if [ -n "$TTY_IN" ]; then
        echo ""
        echo -e "${YELLOW}Configuração do atalho do terminal:${NC}"
        echo -e "  O atalho padrão anterior era '${RED}cc${NC}', que conflita com o compilador C nativo (/usr/bin/cc)."
        echo -e "  Recomendamos '${GREEN}dn${NC}' (DirNav), mas você pode definir o comando que preferir."
        echo ""

        while true; do
            echo -ne "${BLUE}Qual comando de atalho você deseja usar? [padrão: ${GREEN}dn${BLUE}]: ${NC}"
            read -r INPUT_CMD < "$TTY_IN" || INPUT_CMD=""
            INPUT_CMD="$(echo "$INPUT_CMD" | tr -d '[:space:]')"
            [ -z "$INPUT_CMD" ] && INPUT_CMD="dn"

            if ! [[ "$INPUT_CMD" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
                echo -e "${RED}Nome invalido. Use apenas letras, numeros e sublinhado/hifen.${NC}"
                continue
            fi

            # Checa se conflita com algum comando existente no PATH
            EXISTING_BIN="$(type -P "$INPUT_CMD" 2>/dev/null || true)"
            if [ -n "$EXISTING_BIN" ] && [ "$EXISTING_BIN" != "$BIN_DIR/dirnav" ]; then
                echo -e "${RED}Aviso: '${INPUT_CMD}' ja existe no sistema (${EXISTING_BIN}).${NC}"
                echo -ne "${YELLOW}Tem certeza que deseja sobrescrever esse comando na sua sessao? (s/N): ${NC}"
                read -r CONFIRM < "$TTY_IN" || CONFIRM="n"
                if [[ "$CONFIRM" =~ ^[sSyY] ]]; then
                    USER_SHORTCUT="$INPUT_CMD"
                    break
                else
                    continue
                fi
            else
                USER_SHORTCUT="$INPUT_CMD"
                break
            fi
        done
    else
        USER_SHORTCUT="dn"
    fi
fi

if [ -z "$USER_SHORTCUT" ]; then
    USER_SHORTCUT="dn"
fi

echo -e "${GREEN}[✓] Atalho definido: ${BOLD}$USER_SHORTCUT${NC}"

# 5. Monta o bloco de integração para o shell
INTEGRATION_BLOCK="
# Dirnav shell integration
function ${USER_SHORTCUT}() {
    local tmp
    tmp=\"\$(mktemp -t \"dirnav-cwd.XXXXXX\")\"
    command dirnav --cwd-file=\"\$tmp\" \"\$@\"
    if [ -s \"\$tmp\" ]; then
        local target
        target=\"\$(cat \"\$tmp\")\"
        if [ -n \"\$target\" ] && [ -d \"\$target\" ]; then
            builtin cd -- \"\$target\"
        fi
    fi
    rm -f \"\$tmp\"
}
"

if [ "$USER_SHORTCUT" != "dirnav" ]; then
    INTEGRATION_BLOCK="${INTEGRATION_BLOCK}alias dirnav=${USER_SHORTCUT}
"
fi

# Se o usuário escolheu outro comando que não dn, e dn estiver livre, adiciona alias dn
if [ "$USER_SHORTCUT" != "dn" ] && ! command -v dn >/dev/null 2>&1; then
    INTEGRATION_BLOCK="${INTEGRATION_BLOCK}alias dn=${USER_SHORTCUT}
"
fi

# 6. Configura integração no sistema (/etc/profile.d para RHEL/Oracle/Debian/Ubuntu)
if [ -d "/etc/profile.d" ]; then
    printf "%s\n" "$INTEGRATION_BLOCK" | $SUDO tee "/etc/profile.d/dirnav.sh" >/dev/null
    $SUDO chmod +x "/etc/profile.d/dirnav.sh" 2>/dev/null || true
    echo -e "${GREEN}[✓] Integracao global adicionada em: /etc/profile.d/dirnav.sh${NC}"
fi

# 7. Detecta o diretório home do usuário real (mesmo executando com sudo)
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    TARGET_HOME="$HOME"
fi

clean_and_add_rc() {
    local rc_file="$1"
    [ -f "$rc_file" ] || return 0

    # Remove integrações antigas de qualquer função do dirnav
    if grep -q "command dirnav" "$rc_file" || grep -q "# Dirnav shell integration" "$rc_file"; then
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$rc_file" << 'EOF'
import re, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()
content = re.sub(r'\n?# Dirnav shell integration\s+function \w+\(\)\s*\{[^\}]*command dirnav[^\}]*\}(?:\s*alias [^\n]+)*\n?', '\n', content, flags=re.DOTALL)
content = re.sub(r'\n?function \w+\(\)\s*\{[^\}]*command dirnav[^\}]*\}(?:\s*alias [^\n]+)*\n?', '\n', content, flags=re.DOTALL)
content = re.sub(r'^\s*alias (?:gg|cc|dir|dirnav|dn)=.*\n?', '', content, flags=re.MULTILINE)
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
echo -e "${YELLOW}Comando:${NC} ${GREEN}${USER_SHORTCUT}${NC} (ou ${GREEN}dirnav${NC})"
