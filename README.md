# 📂 dirnav

> Navegador de diretórios inline, minimalista e ultrarrápido para terminal, em **Python puro**.

`dirnav` permite navegar pelas pastas do seu sistema de forma rápida e visual diretamente abaixo da linha do comando, sem tela cheia e sem poluir o histórico do seu terminal.

---

## ✨ Recursos

- 🚀 **Modo Inline (Sem Tela Cheia)**: Funciona diretamente abaixo da linha de comando, sem limpar o terminal nem perder seu contexto de tela.
- 🎯 **Apenas Diretórios**: Exibe única e exclusivamente as pastas do diretório atual. Sem poluição com opções extras desnecessárias.
- ⚡ **Zero Dependências**: Feito em Python 3 puro utilizando apenas módulos da biblioteca padrão (`termios`, `tty`, `select`, `os`, `sys`).
- ⌨️ **Navegação Simples e Direta**:
  - `↑` / `↓` — Navega pelas pastas
  - `→` (ou `Enter`) — Entra na pasta selecionada
  - `←` (ou `Backspace`) — Volta um nível (pasta pai)
  - `q` — **Confirma e fica no diretório atual**, saindo do navegador e atualizando o terminal
  - `Esc` / `Ctrl+C` — Cancela e mantém o diretório original
- 🔄 **Integração com Shell**: Altera instantaneamente a pasta atual da sua sessão do shell (`bash` / `zsh`).

---

## 📦 Instalação

### Opção 1: Instalação Rápida (Recomendado)

Cole o comando abaixo no terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/91wallace/dirnav/main/install.sh | bash
```

Após a instalação, reinicie o terminal ou execute:
```bash
source ~/.bashrc  # ou source ~/.zshrc
```

---

### Opção 2: Clonando o Repositório

```bash
git clone https://github.com/91wallace/dirnav.git
cd dirnav
chmod +x install.sh
./install.sh
```

---

## 🚀 Como Usar

No terminal, você pode usar os comandos **`cc`** ou **`dir`**:

```bash
cc
```
*(Recomendado: o comando `cc` funciona perfeitamente em Linux, macOS e Windows sem conflitar com o comando nativo `dir` do PowerShell/CMD).*

Também é possível passar uma pasta inicial:

```bash
cc ~/projects
```

*(Os comandos `dir` e `gg` também ficam configurados como atalhos).*

---

## ⚙️ Como Funciona

1. Ao executar `cc` (ou `dir`), uma função no seu shell cria um arquivo temporário e aciona o script executável `dirnav`.
2. A interface interativa desenha a lista de pastas logo abaixo da linha digitada.
3. Quando você navega e pressiona `q`, o `dirnav` grava o caminho escolhido e encerra limpando a área desenhada.
4. O shell lê o caminho e executa `builtin cd`, atualizando o seu prompt na nova pasta de destino.

---

## 🗑️ Desinstalação

Para desinstalar o `dirnav`:

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
