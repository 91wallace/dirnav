# 📂 dirnav

> Navegador de diretórios inline, minimalista e ultrarrápido para terminal, em **Python puro**.

`dirnav` permite navegar pelas pastas do seu sistema de forma rápida e visual diretamente abaixo da linha do comando, sem tela cheia e sem poluir o histórico do seu terminal.

---

## ✨ Recursos

- 🚀 **Modo Inline (Sem Tela Cheia)**: Funciona diretamente abaixo da linha de comando, sem limpar o terminal nem perder seu contexto de tela.
- 🎯 **Apenas Diretórios**: Exibe única e exclusivamente as pastas do diretório atual. Sem poluição com opções extras desnecessárias.
- ⚡ **Zero Dependências**: Feito em Python 3 puro utilizando apenas módulos da biblioteca padrão (suporta Linux, macOS e Windows com `msvcrt`).
- 🌐 **Comandos Nativos `cc`, `dn` e `dirnav`**: Disponíveis nativamente no PowerShell 7+, Windows PowerShell 5.1, CMD, Bash e Zsh.
- 🔍 **Busca e Filtro Interativo em Tempo Real**: Basta digitar qualquer parte do nome da pasta (inclusive com ou sem acentos) para resumir instantaneamente a lista de diretórios.
- ⌨️ **Navegação Simples e Direta**:
  - `↑` / `↓` — Navega pela lista de pastas
  - `Enter` — **Vai imediatamente para a pasta selecionada** (sem precisar entrar antes)
  - `→` (ou `Tab`) — Entra na subpasta selecionada para continuar explorando subníveis
  - `←` — Volta um nível (pasta pai)
  - `Digitação Livre (A-Z, 0-9, etc.)` — Filtra as pastas em tempo real
  - `Backspace` — **Confirma e mantém no diretório atual** (ou apaga caracteres se houver pesquisa ativa)
  - `Esc` / `Ctrl+C` — **Cancela imediatamente** e sai sem nenhuma alteração
- 🔄 **Integração com Shell**: Altera instantaneamente a pasta atual da sua sessão do shell (`bash`, `zsh` ou `PowerShell 5.1/7+`).

---

## 📦 Instalação

### Multiplataforma via NPM (Windows, Linux, macOS)

```bash
npm install -g dirnav
```
*(Configura automaticamente os comandos `cc`, `dn` e `dirnav` no seu perfil do PowerShell, Bash ou Zsh!)*

---

### Windows via Winget

```powershell
winget install 91wallace.dirnav
dirnav --setup
```

---

### Arch Linux (AUR / Pacman)

```bash
yay -S dirnav
# ou via makepkg:
cd packaging/arch && makepkg -si
```

---

### Linux e macOS (Bash / Zsh via Script)

#### Opção 1: Comando único via `curl` (Recomendado)

```bash
curl -fsSL https://raw.githubusercontent.com/91wallace/dirnav/main/install.sh | bash
```

Após a instalação, reinicie o terminal ou execute:
```bash
source ~/.bashrc  # ou source ~/.zshrc
```

#### Opção 2: A partir do repositório clonado

```bash
git clone https://github.com/91wallace/dirnav.git
cd dirnav
chmod +x install.sh
./install.sh
```

*(O instalador perguntará interativamente qual atalho você prefere usar, sugerindo `dn` por padrão para evitar conflitos com o compilador `cc`, ou você pode passar diretamente `./install.sh --shortcut=dn`).*

---

### Windows (PowerShell 5.1 / PowerShell 7+)

#### Opção 1: Comando único via PowerShell (Recomendado)

Abra o PowerShell e execute:

```powershell
irm https://raw.githubusercontent.com/91wallace/dirnav/main/install.ps1 | iex
```

Após a instalação, recarregue o perfil ou reinicie o terminal:
```powershell
. $PROFILE
```

#### Opção 2: A partir do repositório clonado

```powershell
git clone https://github.com/91wallace/dirnav.git
cd dirnav
.\install.ps1
```

*(O instalador copia o executável para `%LOCALAPPDATA%\Programs\dirnav`, adiciona-o ao seu `PATH` e registra a função `dn` e o alias `dirnav` no `$PROFILE`).*

---

## 🚀 Como Usar

No terminal, basta digitar:

```bash
dn
```
*(ou se preferir, `dirnav` ou o legado `cc` mantido por compatibilidade)*

Também é possível passar uma pasta inicial:

```bash
dn ~/projects
```

---

## ⚙️ Como Funciona

1. Ao executar `cc` ou `dn`, uma função no seu shell cria um arquivo temporário e aciona o script executável `dirnav`.
2. A interface interativa desenha a lista de pastas logo abaixo da linha digitada.
3. Você navega com as setas (`←` / `→` / `↑` / `↓`), digita para filtrar pastas em tempo real e confirma o diretório desejado com `Enter`.
4. O shell lê o caminho retornado e executa `Set-Location -LiteralPath` (no PowerShell) ou `cd` (no Bash/Zsh/CMD), atualizando o seu prompt na nova pasta de destino.

---

## 🗑️ Desinstalação

### Linux/macOS

```bash
curl -fsSL https://raw.githubusercontent.com/91wallace/dirnav/main/uninstall.sh | bash
```

Ou no repositório clonado:
```bash
./uninstall.sh
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/91wallace/dirnav/main/uninstall.ps1 | iex
```

Ou no repositório clonado:
```powershell
.\uninstall.ps1
```

---

## 📄 Licença

Distribuído sob a licença [MIT](LICENSE).
