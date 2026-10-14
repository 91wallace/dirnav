# 📂 dirnav

> Navegador de diretórios inline, minimalista e ultrarrápido para terminal, em **Python puro**.

`dirnav` permite navegar pelas pastas do seu sistema de forma rápida e visual diretamente abaixo da linha do comando, sem tela cheia e sem poluir o histórico do seu terminal.

---

## ✨ Recursos

- 🚀 **Modo Inline (Sem Tela Cheia)**: Funciona diretamente abaixo da linha de comando, sem limpar o terminal nem perder seu contexto de tela.
- 🎯 **Apenas Diretórios**: Exibe única e exclusivamente as pastas do diretório atual. Sem poluição com opções extras desnecessárias.
- ⚡ **Zero Dependências**: Feito em Python 3 puro utilizando apenas módulos da biblioteca padrão (suporta Linux, macOS e Windows com `msvcrt`).
- 🌐 **Comando Universal `cc`**: Não interfere com o comando nativo `dir` do Windows/PowerShell nem com outros comandos do sistema.
- ⌨️ **Navegação Simples e Direta**:
  - `↑` / `↓` — Navega pelas pastas
  - `→` (ou `Enter`) — Entra na pasta selecionada
  - `←` (ou `Backspace`) — Volta um nível (pasta pai)
  - `q` — **Confirma e fica no diretório atual**, saindo do navegador e atualizando o terminal
  - `Esc` / `Ctrl+C` — Cancela e mantém o diretório original
- 🔄 **Integração com Shell**: Altera instantaneamente a pasta atual da sua sessão do shell (`bash`, `zsh` ou `PowerShell 7`).

---

## 📦 Instalação

### Linux e macOS (Bash / Zsh)

#### Opção 1: Comando único via `curl` (Recomendado)

```bash
curl -fsSL https://raw.githubusercontent.com/91wallace/dirnav/main/install.sh | bash
```

Após a instalação, reinicie o terminal ou execute:
```bash
source ~/.bashrc  # ou source ~/.zshrc
```

#### Opção 2: Clonando o repositório

```bash
git clone https://github.com/91wallace/dirnav.git
cd dirnav
chmod +x install.sh
./install.sh
```

---

### Windows (PowerShell 7)

1. Baixe o script executável `dirnav` para uma pasta no seu `PATH` (ex: `C:\Users\<usuario>\AppData\Local\Programs\Python\...` ou similar).
2. Adicione a função `cc` ao seu perfil do PowerShell (`notepad $PROFILE`):

```powershell
function cc {
    param([string]$Path)
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        if ($Path) { python -m dirnav --cwd-file="$tmp" "$Path" }
        else { python -m dirnav --cwd-file="$tmp" }
        if (Test-Path $tmp) {
            $target = (Get-Content $tmp -Raw).Trim()
            if ($target -and (Test-Path $target)) { Set-Location $target }
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
    }
}
```
*(Dessa forma o comando nativo `dir` do PowerShell continua funcionando normalmente para listar itens, enquanto o `cc` aciona o navegador interativo).*

---

## 🚀 Como Usar

No terminal, basta digitar:

```bash
cc
```

Também é possível passar uma pasta inicial:

```bash
cc ~/projects
```

*(No Linux, os aliases `dir` e `gg` também ficam disponíveis para conveniência).*

---

## ⚙️ Como Funciona

1. Ao executar `cc`, uma função no seu shell cria um arquivo temporário e aciona o script executável `dirnav`.
2. A interface interativa desenha a lista de pastas logo abaixo da linha digitada.
3. Quando você navega e pressiona `q`, o `dirnav` grava o caminho escolhido e encerra limpando a área desenhada.
4. O shell lê o caminho e executa `cd` (ou `Set-Location` no PowerShell), atualizando o seu prompt na nova pasta de destino.

---

## 🗑️ Desinstalação (Linux/macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/91wallace/dirnav/main/uninstall.sh | bash
```

Ou no repositório clonado:
```bash
./uninstall.sh
```

---

## 📄 Licença

Distribuído sob a licença [MIT](LICENSE).
