$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$DirnavPs1 = Join-Path $ProjectRoot "dirnav.ps1"
$InstallPs1 = Join-Path $ProjectRoot "install.ps1"
$UninstallPs1 = Join-Path $ProjectRoot "uninstall.ps1"

$Passed = 0
$Failed = 0

function Assert-True($Condition, $Message) {
    if ($Condition) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        $script:Failed++
    }
}

Write-Host "==> Executando Suite de Testes PowerShell 7 (Dirnav)" -ForegroundColor Cyan

# Teste 1: Carregamento de dirnav.ps1 e disponibilidade nativa de 'cc', 'dn' e 'dirnav'
Write-Host "`n[1] Testando integracao nativa de comandos (cc, dn, dirnav)..." -ForegroundColor Yellow
. $DirnavPs1

$cmdCc = Get-Command cc -ErrorAction SilentlyContinue
$cmdDn = Get-Command dn -ErrorAction SilentlyContinue
$cmdDirnav = Get-Command dirnav -ErrorAction SilentlyContinue

Assert-True ($null -ne $cmdCc) "Comando 'cc' esta registrado nativamente na sessao PowerShell"
Assert-True ($null -ne $cmdDn) "Comando 'dn' esta registrado nativamente na sessao PowerShell"
Assert-True ($null -ne $cmdDirnav) "Alias 'dirnav' esta registrado na sessao PowerShell"

# Teste 2: Navegacao para diretorios com colchetes e espacos via mock de dirnav.cmd (Bug Critico 6)
Write-Host "`n[2] Testando navegacao com 'cc' em caminhos contendo colchetes 'Pasta [2026]' e acentos..." -ForegroundColor Yellow
$TestSandbox = Join-Path ([System.IO.Path]::GetTempPath()) "dirnav-ps-test-$([guid]::NewGuid().ToString('N'))"
$SpecialDir = Join-Path $TestSandbox "Configurações [2026]"
New-Item -ItemType Directory -Force -Path $SpecialDir | Out-Null

$OrigLocation = Get-Location
try {
    # Mock de dirnav.cmd para escrever o caminho especial no --cwd-file
    function dirnav.cmd {
        param([string]$Arg1, [string]$Arg2)
        if ($Arg1 -match "^--cwd-file=(.+)$") {
            $cwdFile = $Matches[1].Trim('"')
            [System.IO.File]::WriteAllText($cwdFile, $SpecialDir, [System.Text.Encoding]::UTF8)
        }
    }

    cc
    $CurrentLoc = (Get-Location).Path
    Assert-True ($CurrentLoc -eq $SpecialDir) "Comando 'cc' mudou com sucesso para pasta com colchetes e acentos: $CurrentLoc"
} finally {
    Set-Location -LiteralPath $OrigLocation.Path
    Remove-Item -Path Function:\dirnav.cmd -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $TestSandbox) {
        Remove-Item -Recurse -Force -LiteralPath $TestSandbox -ErrorAction SilentlyContinue
    }
}

# Teste 3: Ciclo completo de install.ps1 (idempotencia) e uninstall.ps1 (limpeza sem aliases orfaos - Bug Critico 5)
Write-Host "`n[3] Testando install.ps1 (idempotencia) e uninstall.ps1 (limpeza total do PROFILE)..." -ForegroundColor Yellow
$InstallSandbox = Join-Path ([System.IO.Path]::GetTempPath()) "dirnav-install-test-$([guid]::NewGuid().ToString('N'))"
$MockInstallDir = Join-Path $InstallSandbox "bin"
$MockProfile = Join-Path $InstallSandbox "Microsoft.PowerShell_profile.ps1"

try {
    $env:DIRNAV_INSTALL_DIR = $MockInstallDir
    $env:DIRNAV_TEST_PROFILE = $MockProfile
    $env:DIRNAV_SKIP_PATH = "1"

    # Cria conteudo previo no profile para garantir que o instalador/desinstalador preserva configuracoes do usuario
    New-Item -ItemType Directory -Force -Path $InstallSandbox | Out-Null
    Set-Content -LiteralPath $MockProfile -Value "# Configuracao do usuario`r`n`$env:MY_VAR = '123'" -Encoding utf8

    # Primeira execucao do install.ps1
    & $InstallPs1 -Shortcut "dn" -NonInteractive | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $MockInstallDir "dirnav.py")) "install.ps1 copiou dirnav.py"
    Assert-True (Test-Path -LiteralPath (Join-Path $MockInstallDir "dirnav.cmd")) "install.ps1 gerou launcher dirnav.cmd"
    Assert-True (Test-Path -LiteralPath (Join-Path $MockInstallDir "cc.cmd")) "install.ps1 gerou launcher nativo cc.cmd"

    # Segunda execucao do install.ps1 (teste de idempotencia)
    & $InstallPs1 -Shortcut "dn" -NonInteractive | Out-Null
    $profContent = Get-Content -LiteralPath $MockProfile -Raw -Encoding utf8
    $matchesCount = ([regex]::Matches($profContent, "# Dirnav shell integration")).Count
    Assert-True ($matchesCount -eq 1) "install.ps1 e idempotente (apenas 1 bloco no PROFILE apos multiplas execucoes)"
    Assert-True ($profContent -match "Set-Alias -Name cc") "PROFILE contem alias nativo 'cc'"
    Assert-True ($profContent -match "Set-Location -LiteralPath") "PROFILE utiliza Set-Location -LiteralPath"

    # Execucao do uninstall.ps1
    & $UninstallPs1 | Out-Null
    Assert-True (-not (Test-Path -LiteralPath $MockInstallDir)) "uninstall.ps1 removeu diretorio de instalacao"

    $profAfterUninstall = Get-Content -LiteralPath $MockProfile -Raw -Encoding utf8
    Assert-True ($profAfterUninstall -notmatch "Set-Alias -Name cc") "uninstall.ps1 removeu completamente alias 'cc' (sem aliases orfaos)"
    Assert-True ($profAfterUninstall -notmatch "Set-Alias -Name dirnav") "uninstall.ps1 removeu completamente alias 'dirnav'"
    Assert-True ($profAfterUninstall -match "MY_VAR") "uninstall.ps1 preservou configuracoes originais do usuario no PROFILE"
} finally {
    Remove-Item Env:\DIRNAV_INSTALL_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:\DIRNAV_TEST_PROFILE -ErrorAction SilentlyContinue
    Remove-Item Env:\DIRNAV_SKIP_PATH -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $InstallSandbox) {
        Remove-Item -Recurse -Force -LiteralPath $InstallSandbox -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Resumo PowerShell Tests: $Passed passaram, $Failed falharam." -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "=========================================" -ForegroundColor Cyan

if ($Failed -gt 0) {
    exit 1
}
