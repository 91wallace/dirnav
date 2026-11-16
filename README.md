# dirnav

Navegação interativa de diretórios para terminal, escrita em Python. O dirnav exibe uma lista filtrável de pastas no próprio terminal e permite mudar o diretório da sessão do shell.

[English README](README.en.md) | [Release Windows 1.0.1-beta.1](https://github.com/91wallace/dirnav/releases/tag/v1.0.1-beta.1)

> **Estado da versão:** a versão pública `1.0.1-beta.1` é uma beta experimental para Windows x64, destinada a avaliadores selecionados. Não é uma versão estável nem foi aprovada para distribuição geral ou ambientes críticos.

## Recursos

- Navegação inline, sem interface de tela cheia.
- Filtro de arquivos e diretórios enquanto você digita.
- Árvore de diretórios com ícones de pasta aberta/fechada e recuo de até três níveis.
- Os atalhos disponíveis são listados por `dirnav --help` ou `dirnav -h`; a interface não exibe barras persistentes.
- Seleção com Enter; navegação entre níveis e cancelamento com Esc.
- `F5` copia o item selecionado para um destino escolhido, com verificação e confirmação para conflitos.
- `F6` move o item selecionado; movimentos entre volumes copiam e verificam antes de remover a origem.
- A lista começa mostrando somente diretórios. `F7` alterna entre arquivos e somente diretórios.
- `--all` ou `-a` inicia com arquivos comuns, ocultos e do sistema visíveis; `F7` alterna entre arquivos e somente diretórios.
- `Del` solicita confirmação antes de apagar; a exclusão é permanente e recursiva para diretórios.
- `Enter` seleciona o diretório para a integração com o shell; `Tab` ou `→` entra nele.
- Integração para alterar a localização da sessão em CMD e PowerShell.
- Código Python que usa a biblioteca padrão, sem dependências externas de runtime para a aplicação.

```powershell
py -3 .\dirnav --help
py -3 .\dirnav --all
py -3 .\dirnav -a C:\caminho\para\pasta
```

`q` continua sendo texto de busca e `Esc` cancela a navegação ou a operação atual. A árvore e as operações de arquivo estão em desenvolvimento e **não fazem parte** do ZIP publicado `1.0.1-beta.1`.

Os detalhes de segurança, decisões de compatibilidade e validação desta evolução estão em [docs/development/tui-file-operations.md](docs/development/tui-file-operations.md).

## Compatibilidade e estado de validação

| Ambiente | Estado |
| --- | --- |
| Windows x64, CMD | Incluído na beta; testes locais em `cmd.exe` real. |
| Windows PowerShell 5.1 e PowerShell 7 | Incluídos no escopo da beta; integração temporária descrita no guia. |
| Linux e macOS | Não homologados. |
| Bash e Zsh | Em estabilização; testes em Git Bash no Windows não equivalem a homologação Linux/macOS. |
| Arch/AUR, Winget e npm | Não fazem parte da beta Windows publicada; não instalar como pacotes aprovados. |

A beta não deve ser usada em ambientes críticos. A avaliação positiva externa foi informada pelo proprietário, mas não há relatórios detalhados ou métricas publicados neste repositório.

## Instalar a beta Windows

Baixe apenas o ZIP e `SHA256SUMS.txt` da [release 1.0.1-beta.1](https://github.com/91wallace/dirnav/releases/tag/v1.0.1-beta.1). Confira o hash antes de extrair ou executar:

```powershell
$Zip = Join-Path $HOME 'Downloads\dirnav-1.0.1-beta.1-windows-x64.zip'
$Expected = '9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077'
$Actual = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Actual -ne $Expected) { throw 'SHA-256 divergente; não execute o pacote.' }
```

Extraia o arquivo para uma pasta dedicada do seu usuário, por exemplo `%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1`. Para iniciar a navegação no CMD, use `call` na mesma sessão:

```cmd
call "%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1\cc.cmd"
```

O [guia de avaliação](docs/pilot/windows-beta-evaluation.md) contém instruções para CMD, Windows PowerShell 5.1 e PowerShell 7, além de uma lista de testes de seleção, cancelamento e metacaracteres.

### Desinstalar a beta Windows

Feche as sessões de teste e remova somente a pasta dedicada que você criou para a extração, por exemplo `%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1`. Confira o caminho antes de apagá-lo. A beta ZIP não instala serviços nem exige alteração de perfil ou PATH.

## Limitações de segurança e caminhos

- A homologação adversarial F15 com uma segunda identidade Windows padrão não foi realizada. Não está comprovado que outra conta padrão seja impedida de alterar o batch auxiliar temporário.
- Há uma limitação conhecida com caminhos longos no Windows. Evite árvores de diretórios muito profundas.
- Linux e macOS ainda não foram homologados.
- A versão estável Windows permanece **NO-GO** até que a homologação adversarial e os critérios de segurança pendentes sejam concluídos.

Consulte [aceitação do risco F15](docs/security/release-risk-acceptance.md), [relatório da release](docs/release/publication-v1.0.1-beta.1.md) e [matriz de testes](docs/audit/test-matrix.md) para o escopo e as evidências disponíveis.

## Desenvolvimento

Requisitos para executar os testes Python: Python 3 e `pytest`; Ruff é usado para lint.

```powershell
py -3 -m pytest -q -rs
py -3 -m ruff check dirnav tests/
```

Os testes específicos de shell e instaladores estão em `tests/shell/`. Consulte a documentação de auditoria antes de interpretar testes simulados como validação de um sistema operacional nativo.

## Segurança e relatos de problemas

Não envie tokens, credenciais, perfis completos, caminhos pessoais ou conteúdo de arquivos temporários em issues. Revise e remova dados sensíveis dos diagnósticos antes de compartilhá-los. O [modelo de feedback do piloto](docs/pilot/feedback-template.md) explica quais resultados são úteis sem coletar dados automaticamente. O dirnav não envia telemetria.

## Licença

Distribuído sob a licença [MIT](LICENSE).
