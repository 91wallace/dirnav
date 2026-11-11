# dirnav 1.0.1-beta.1 — Windows x64 (Pre-release)

**Beta experimental para Windows x64. Não homologada para distribuição geral ou uso em ambientes críticos.**

## O que há nesta beta

- Navegação interativa por diretórios no terminal, com filtro por digitação.
- Setas para navegar, Enter para selecionar, Backspace para voltar e Esc para cancelar sem alterar a localização.
- Wrappers CMD (`cc.cmd`, `dn.cmd`, `dirnav.cmd`) que aplicam a seleção na mesma sessão CMD.
- Compatibilidade exercitada localmente em `cmd.exe`, Windows PowerShell 5.1 e PowerShell 7. No PowerShell, use a função temporária documentada no guia de avaliação; não é necessário editar perfil.

## Instalação

Baixe somente `dirnav-1.0.1-beta.1-windows-x64.zip` e `SHA256SUMS.txt` desta release. Confirme o SHA-256 também com o responsável por um canal separado:

```powershell
$Zip = Join-Path $PWD 'dirnav-1.0.1-beta.1-windows-x64.zip'
$Expected = '9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077'
$Actual = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Actual -ne $Expected) { throw 'SHA-256 divergente; não execute o pacote.' }
```

Extraia para uma pasta sua, por exemplo `%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1`. Em CMD, execute:

```cmd
call "%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1\cc.cmd"
```

O [guia completo de avaliação](https://github.com/91wallace/dirnav/blob/v1.0.1-beta.1/docs/pilot/windows-beta-evaluation.md) descreve os passos CMD, PowerShell 5.1 e PowerShell 7, incluindo a integração temporária no PowerShell.

Para remover, feche as sessões de teste e apague somente a pasta exclusiva `DirnavPilot\1.0.1-beta.1` sob `%LOCALAPPDATA%`.

## Compatibilidade e validação

- Windows x64: regressões locais executadas em CMD real, Windows PowerShell 5.1 e PowerShell 7. A suíte Python/CMD mais recente teve 46 testes aprovados e 1 skip por falha do filesystem em criar o cenário longo (WinError 206); PS 5.1 e PS 7 tiveram 16/16 cada.
- O proprietário informa que avaliadores externos deram feedback positivo. Não foram fornecidos relatórios detalhados ou métricas e esta nota não os inventa.
- Linux e macOS não estão homologados. Bash/Zsh e os pacotes Arch, Winget e npm não fazem parte desta distribuição beta.

## Limitações e segurança

- Homologação adversarial F15 com segunda identidade Windows **não realizada**. A possibilidade de outra conta padrão alterar o batch auxiliar não foi comprovada nem descartada.
- Caminhos longos: limitação conhecida. O host de desenvolvimento não criou o cenário >260 caracteres (WinError 206), e o CMD rejeitou o prefixo estendido `\\?\` como diretório atual. Evite caminhos profundos.
- Beta experimental; sem garantia de prontidão para ambientes críticos.
- A versão estável permanece **NO-GO** até concluir a homologação adversarial Windows e os critérios de segurança pendentes.

## Integridade

SHA-256: `9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077`.
