# dirnav

Navegador interativo de diretórios e arquivos para terminal, em Python. A versão mantida do código é `1.0.0` e usa o mesmo núcleo em Windows, Ubuntu e Arch Linux; as integrações de shell e pacotes são específicas de cada sistema.

[English README](README.en.md)

## Recursos

- Navegação inline com filtro e árvore de diretórios.
- Cópia, movimentação e exclusão com confirmação e verificações para proteger os dados.
- Integração com CMD e PowerShell no Windows e Bash/Zsh em sistemas POSIX.
- Implementação Python sem dependências externas em runtime.

## Requisitos

- Python 3.
- Windows: CMD, Windows PowerShell 5.1 ou PowerShell 7.
- Linux e macOS: Bash ou Zsh para atualizar o diretório da sessão atual.

## Instalação

### Windows

No clone do repositório, execute no PowerShell:

```powershell
.\install.ps1
```

O instalador configura os launchers e a integração do perfil do usuário. Reinicie o shell ou carregue novamente o perfil.

### Linux e macOS

No clone do repositório, execute:

```bash
bash ./install.sh
```

A instalação é por usuário, em `~/.local/bin`; abra um shell novo ou carregue novamente o perfil Bash/Zsh.

### Arch Linux

```bash
cd packaging/arch
makepkg -si
dirnav --setup
```

O pacote não altera automaticamente os perfis pessoais. Use `dirnav --uninstall` para remover a integração antes de remover o pacote.

## Uso

```text
dirnav --help
dirnav --all
dirnav -a /caminho/para/pasta
```

O comando configurado no shell (`dn` por padrão) permite que a seleção atualize o diretório da sessão. `Enter` confirma a pasta, `Tab` ou `→` entra nela, `Esc` cancela. `F5`, `F6` e `Del` iniciam cópia, movimentação e exclusão; consulte `dirnav --help` para os atalhos completos.

## Desenvolvimento e testes

```bash
python -m pytest tests/ -v
ruff check dirnav dirnav_operations.py tests/
ruff format --check dirnav dirnav_operations.py tests/
bash ./tests/shell/test_bash.sh
bash ./tests/shell/test_installers.sh
```

Os testes PowerShell estão em `tests/shell/Dirnav.Tests.ps1`. O teste CMD requer Windows; o teste Zsh requer Zsh instalado. O instalador Bash instala em `~/.local/bin` e configura Bash/Zsh; no macOS, confirme que esse diretório está no `PATH`.

## Histórico

Os documentos em `docs/pilot/`, `docs/release/` e `docs/security/` preservam o registro da antiga distribuição Windows `1.0.1-beta.1`. Ela não é a versão do código atual.

## Licença

MIT. Consulte [LICENSE](LICENSE).
