<#
.SYNOPSIS
    Script de instalacao automatica do dirnav no Windows (PowerShell 5.1 / PowerShell 7+)
.DESCRIPTION
    1. Baixa/Copia o script 'dirnav' e cria os launchers 'dirnav.cmd' e 'cc.cmd'.
    2. Instala em pasta no PATH do usuario ($env:LOCALAPPDATA\Programs\dirnav).
    3. Configura a integracao e o comando nativo 'cc' nos perfis do PowerShell 7 e Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Shortcut = "dn",

    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

$RepoRawUrl = "https://raw.githubusercontent.com/91wallace/dirnav/main"
$InstallDir = if ($env:DIRNAV_INSTALL_DIR) { $env:DIRNAV_INSTALL_DIR } else { "$env:LOCALAPPDATA\Programs\dirnav" }

Write-Host "==> Instalando dirnav no Windows..." -ForegroundColor Cyan

# 1. Verifica Python 3 (ignora o stub da Microsoft Store testando --version)
$pythonCmd = $null
foreach ($candidate in @("py", "python3", "python")) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            $ver = & $candidate --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $ver -match "Python 3") {
                $pythonCmd = $candidate
                break
            }
        } catch {
            # Ignora candidatos invalidos
        }
    }
}

if (-not $pythonCmd) {
    Write-Error "Python 3 nao foi encontrado no PATH. Por favor, instale o Python 3 antes de continuar."
    exit 1
}

# 2. Cria diretorio de destino
if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

# 3. Copia ou baixa o arquivo 'dirnav'
$localDirnav = Join-Path $PSScriptRoot "dirnav"
$targetScript = Join-Path $InstallDir "dirnav.py"

if (Test-Path -LiteralPath $localDirnav) {
    Copy-Item -LiteralPath $localDirnav -Destination $targetScript -Force
} else {
    Write-Host "Baixando dirnav de $RepoRawUrl/dirnav..." -ForegroundColor Gray
    curl.exe -fsSL "$RepoRawUrl/dirnav" -o "$targetScript"
}

# 4. Cria wrappers executaveis 'dirnav.cmd' e 'cc.cmd'
$cmdLauncher = Join-Path $InstallDir "dirnav.cmd"
$cmdContent = "@echo off`r`n`"$pythonCmd`" `"$targetScript`" %*`r`n"
[System.IO.File]::WriteAllText($cmdLauncher, $cmdContent)

$ccLauncher = Join-Path $InstallDir "cc.cmd"
[System.IO.File]::WriteAllText($ccLauncher, $cmdContent)

# 5. Adiciona InstallDir ao PATH do usuario caso nao esteja (apenas se nao for teste customizado)
if (-not $env:DIRNAV_SKIP_PATH) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if (($userPath -split ';') -notcontains $InstallDir) {
        $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
        $env:Path = "$InstallDir;$env:Path"
        Write-Host "[OK] Adicionado ao PATH do usuario: $InstallDir" -ForegroundColor Green
    } else {
        Write-Host "[i] $InstallDir ja esta no PATH." -ForegroundColor Gray
    }
}

# 6. Escolha do comando de atalho
if (-not $PSBoundParameters.ContainsKey('Shortcut') -and -not $NonInteractive) {
    try {
        Write-Host ""
        Write-Host "Configuracao do atalho do terminal:" -ForegroundColor Yellow
        Write-Host "  Recomendamos 'dn' (DirNav), e 'cc' tambem ficara disponivel nativamente." -ForegroundColor Gray
        $prompt = Read-Host "Qual comando de atalho principal deseja usar? [padrao: dn]"
        if ($prompt -and $prompt.Trim()) {
            $Shortcut = $prompt.Trim()
        } else {
            $Shortcut = "dn"
        }
    } catch {
        $Shortcut = "dn"
    }
}

Write-Host "[OK] Atalho configurado: $Shortcut (e 'cc' habilitado)" -ForegroundColor Green

# 7. Monta o bloco de integracao com delimitadores claros
$integrationBlock = @"
# Dirnav shell integration
function $Shortcut {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=`$true)]
        [string]`$Path
    )

    `$tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "dirnav-cwd-`$([guid]::NewGuid().ToString('N')).tmp")
    try {
        if (`$Path) {
            dirnav.cmd --cwd-file="`$tmp" "`$Path"
        } else {
            dirnav.cmd --cwd-file="`$tmp"
        }
        if (Test-Path -LiteralPath `$tmp) {
            `$raw = Get-Content -LiteralPath `$tmp -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if (`$null -ne `$raw) {
                `$target = `$raw.Trim()
                if (`$target -and (Test-Path -LiteralPath `$target -PathType Container)) {
                    Set-Location -LiteralPath `$target
                }
            }
        }
    } finally {
        if (Test-Path -LiteralPath `$tmp) {
            Remove-Item -LiteralPath `$tmp -Force -ErrorAction SilentlyContinue
        }
    }
}
Set-Alias -Name dirnav -Value $Shortcut -Option AllScope -Force -ErrorAction SilentlyContinue
Set-Alias -Name cc -Value $Shortcut -Option AllScope -Force -ErrorAction SilentlyContinue
# END Dirnav shell integration
"@

# 8. Determina os perfis alvo (PowerShell 7 Core e Windows PowerShell 5.1, ou perfil de teste)
$targetProfiles = @()
if ($env:DIRNAV_TEST_PROFILE) {
    $targetProfiles += $env:DIRNAV_TEST_PROFILE
} else {
    $docs = [Environment]::GetFolderPath("MyDocuments")
    if ($docs) {
        $targetProfiles += Join-Path $docs "PowerShell\Microsoft.PowerShell_profile.ps1"
        $targetProfiles += Join-Path $docs "PowerShell\profile.ps1"
        $targetProfiles += Join-Path $docs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        $targetProfiles += Join-Path $docs "WindowsPowerShell\profile.ps1"
    }
    if ($PROFILE -and ($targetProfiles -notcontains $PROFILE)) {
        $targetProfiles += $PROFILE
    }
}

$pattern = "(?ms)# Dirnav shell integration.*?# END Dirnav shell integration|# Dirnav shell integration\s+function \w+\b.*?(?:Set-Alias -Name cc[^\r\n]*\r?\n?)"

foreach ($prof in ($targetProfiles | Select-Object -Unique)) {
    $profDir = Split-Path $prof -Parent
    if (-not (Test-Path -LiteralPath $profDir)) {
        New-Item -ItemType Directory -Force -Path $profDir | Out-Null
    }
    if (-not (Test-Path -LiteralPath $prof)) {
        New-Item -ItemType File -Force -Path $prof | Out-Null
    }

    $profileContent = Get-Content -LiteralPath $prof -Raw -ErrorAction SilentlyContinue
    if ($null -eq $profileContent) {
        $profileContent = ""
    }

    if ($profileContent -match "# Dirnav shell integration") {
        $cleanProfile = [System.Text.RegularExpressions.Regex]::Replace($profileContent, $pattern, "")
        $newContent = if ($cleanProfile.Trim()) { $cleanProfile.Trim() + "`r`n`r`n" + $integrationBlock + "`r`n" } else { $integrationBlock + "`r`n" }
        Set-Content -LiteralPath $prof -Value $newContent -Encoding utf8
        Write-Host "[OK] Integracao atualizada no perfil: $prof" -ForegroundColor Green
    } else {
        $newContent = if ($profileContent.Trim()) { $profileContent.Trim() + "`r`n`r`n" + $integrationBlock + "`r`n" } else { $integrationBlock + "`r`n" }
        Set-Content -LiteralPath $prof -Value $newContent -Encoding utf8
        Write-Host "[OK] Integracao adicionada ao perfil: $prof" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Instalacao concluida com sucesso!" -ForegroundColor Green
Write-Host "Para utilizar na sessao atual:" -ForegroundColor Yellow
Write-Host "  . `$PROFILE" -ForegroundColor Cyan
Write-Host "Comandos disponiveis: $Shortcut, cc, dirnav" -ForegroundColor Yellow
