# Piloto Windows — dirnav 1.0.1-beta.1

**Estado:** o proprietário informa que houve avaliação externa com feedback positivo. Não foram fornecidos relatórios detalhados ou métricas nesta documentação; nenhum resultado adicional é inferido. Este documento continua sendo o checklist para avaliadores selecionados.

## Escopo e segurança

Este piloto avalia somente o ZIP Windows compartilhado diretamente com avaliadores delimitados. Ele não foi publicado em registro público. A aceitação do risco residual F15 permite este piloto e **não** demonstra que outra conta Windows padrão não pode alterar o batch temporário. Não use o pacote para dados ou ambientes críticos. Homologação adversarial cross-identity segue obrigatória antes de versão estável.

Os comandos abaixo não editam perfis do PowerShell, PATH, registro ou ACLs globais. Os wrappers CMD criam e removem seus próprios artefatos temporários de navegação. Não execute como administrador.

## 1. Verifique o arquivo recebido

Use o SHA-256 por canal separado abaixo. Não extraia nem execute se o hash divergir.

```powershell
$Zip = Join-Path $HOME 'Downloads\dirnav-1.0.1-beta.1-windows-x64.zip'
$Expected = '9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077'
$Actual = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Actual -ne $Expected) { throw "SHA-256 divergente: $Actual" }
```

Extraia em uma pasta sua, por exemplo:

```powershell
$PilotDir = Join-Path $env:LOCALAPPDATA 'DirnavPilot\1.0.1-beta.1'
New-Item -ItemType Directory -Force -Path $PilotDir | Out-Null
Expand-Archive -LiteralPath $Zip -DestinationPath $PilotDir -Force
& (Join-Path $PilotDir 'dirnav.exe') --version
```

O resultado esperado é `dirnav 1.0.1-beta.1`. Para desinstalar, feche as sessões de teste e remova somente essa pasta `DirnavPilot\1.0.1-beta.1` pelo Explorer. Confira o caminho antes de remover. Nenhuma outra pasta do usuário deve ser removida.

## 2. Teste no CMD

Abra um CMD normal, sem elevação. Substitua o caminho pelo diretório de extração. `call` mantém a execução na sessão chamadora:

```cmd
call "%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1\cc.cmd"
```

Também podem ser usados `dn.cmd` e `dirnav.cmd`. Navegue até uma pasta descartável, pressione Enter para selecionar e confirme que `cd` mostra o destino na mesma sessão. Abra sessões distintas com delayed expansion desligada e ligada:

```cmd
cmd.exe /v:off
cmd.exe /v:on
```

Em cada uma, teste seleção de diretórios com espaços e Unicode; se possível, inclua `&`, `^`, `%`, `!` e parênteses válidos em nomes Windows. Teste Esc e confirme que o diretório atual não mudou. A troca entre unidades pode ser testada se houver uma segunda unidade descartável disponível.

## 3. Teste no PowerShell 5.1 e PowerShell 7

Faça os testes em cada versão separadamente. O trecho abaixo registra uma função somente na sessão atual; não salve no perfil. Ajuste `$PilotDir` para a pasta extraída.

```powershell
$global:DirnavPilotExe = Join-Path $PilotDir 'dirnav.exe'
if (-not (Test-Path -LiteralPath $global:DirnavPilotExe -PathType Leaf)) { throw 'dirnav.exe não encontrado' }

function global:dn {
    param([Parameter(Position=0)][string]$Path)
    $cwdFile = Join-Path ([IO.Path]::GetTempPath()) ("dirnav-pilot-" + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $nativeArgs = @('--cwd-file', $cwdFile)
        if ($PSBoundParameters.ContainsKey('Path')) { $nativeArgs += $Path }
        & $global:DirnavPilotExe @nativeArgs
        $status = $LASTEXITCODE
        if ($status -eq 0 -and (Test-Path -LiteralPath $cwdFile -PathType Leaf)) {
            $target = [IO.File]::ReadAllText($cwdFile, [Text.Encoding]::UTF8).Trim()
            if ($target -and (Test-Path -LiteralPath $target -PathType Container)) {
                Set-Location -LiteralPath $target
            }
        } elseif ($status -ne 0) {
            Write-Warning "dirnav terminou com status $status; a localização não foi alterada."
        }
    } finally {
        if (Test-Path -LiteralPath $cwdFile) { Remove-Item -LiteralPath $cwdFile -Force -ErrorAction SilentlyContinue }
    }
}
Set-Alias -Scope Global -Name cc -Value dn -Force
Set-Alias -Scope Global -Name dirnav -Value dn -Force
```

Execute `dn`, selecione uma pasta de teste e confira `Get-Location`. Teste também Esc e confirme que a localização não mudou. Use uma pasta com espaços/Unicode. Registre separadamente o resultado do Windows PowerShell 5.1 e do PowerShell 7.

Ao terminar a sessão de teste, remova a integração temporária:

```powershell
Remove-Item Function:\global:dn -ErrorAction SilentlyContinue
Remove-Item Alias:\global:cc -ErrorAction SilentlyContinue
Remove-Item Alias:\global:dirnav -ErrorAction SilentlyContinue
Remove-Variable DirnavPilotExe -Scope Global -ErrorAction SilentlyContinue
```

## 4. Checklist por avaliador

- [ ] Hash do ZIP confere com o valor publicado neste documento.
- [ ] `dirnav.exe --version` informa `1.0.1-beta.1`.
- [ ] CMD: seleção altera o diretório da mesma sessão.
- [ ] CMD: delayed expansion `/v:off` e `/v:on` testadas separadamente.
- [ ] CMD: espaço, Unicode e metacaracteres válidos testados quando disponíveis.
- [ ] CMD: cancelar preserva o diretório; `cd /d` permite trocar unidade quando disponível.
- [ ] PowerShell 5.1: seleção e cancelamento verificados na sessão atual.
- [ ] PowerShell 7: seleção e cancelamento verificados na sessão atual.
- [ ] Não houve execução inesperada, destino incorreto, alteração após cancelamento ou arquivo temporário residual.
- [ ] Se ocorreu falha, foi preenchido o modelo de feedback sem anexar caminhos pessoais ou dados sensíveis.

Não marque testes de shells que não executou. Não compartilhe resultados como homologação externa até que o próprio avaliador os tenha realizado.

## 5. Feedback e diagnóstico opcional

O dirnav não envia telemetria. O avaliador decide se quer compartilhar o formulário em [feedback-template.md](feedback-template.md). Diagnóstico é manual e opcional; copie somente as saídas relevantes e revise antes de enviar:

```powershell
$PSVersionTable.PSVersion
[Environment]::OSVersion.Version
& (Join-Path $PilotDir 'dirnav.exe') --version
cmd.exe /c ver
```

Não inclua nomes de usuário, hostname, conteúdo de perfis, variáveis de ambiente, tokens, listagens de diretórios, nomes de pastas pessoais ou o conteúdo de batches temporários. Para reproduções, substitua caminhos pessoais por exemplos como `<perfil>\pasta de teste`.

## 6. Critérios para encerrar o piloto

O piloto só pode ser fechado quando:

1. Há ao menos um registro preenchido para cada ambiente declarado: CMD, Windows PowerShell 5.1 e PowerShell 7. Os ambientes sem avaliador permanecem **NOT TESTED**.
2. Todos os avaliadores usados verificaram o SHA-256 antes de executar o ZIP.
3. Cada registro informa seleção, cancelamento e, para CMD, delayed expansion ligada/desligada; metacaracteres/unidades são marcados como não testados quando indisponíveis.
4. Não existe defeito reproduzível de severidade crítica/alta em aberto para os cenários do piloto.
5. Toda falha funcional reproduzível foi corrigida e passou pela regressão local apropriada antes de qualquer nova beta.
6. O responsável consolidou resultados e resíduos de teste sem apagar os receipts F15.

Uma vulnerabilidade de execução/injeção, destino incorreto, mudança de diretório ao cancelar, batch alterável por outra conta ou resíduo não removido encerra o piloto como **FAIL/NO-GO** até investigação e correção. Um cenário não executado não conta como aprovação.

## 7. Decidir sobre uma nova beta

- **Manter 1.0.1-beta.1:** todos os critérios de encerramento passaram, sem bugs críticos/altos; manter explicitamente o limite F15.
- **Preparar nova beta:** qualquer defeito reproduzível exige correção, atualização do changelog, regressões completas, novo ZIP/hash e instruções versionadas. O ZIP atual não deve ser sobrescrito.
- **Interromper/NO-GO:** risco crítico/alto não mitigado, evidência de injeção, batch substituível ou teste essencial sem resultado suficiente.
- **Versão estável:** além do piloto aprovado, exige homologação adversarial Windows real com segunda identidade padrão, revisão dos riscos de filesystem/long paths e validação dos instaladores/pacotes dos sistemas que forem declarados compatíveis. A aceitação F15 da beta não substitui essa prova.
