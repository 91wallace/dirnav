<#
.SYNOPSIS
    Script de instalacao automatica do dirnav no Windows (PowerShell 5.1 / PowerShell 7+)
.DESCRIPTION
    1. Baixa/Copia o script 'dirnav' e cria o launcher 'dirnav.cmd'.
    2. Instala em pasta no PATH do usuario ($env:LOCALAPPDATA\Programs\dirnav).
    3. Registra a funcao 'dn' e o alias 'dirnav' no perfil do PowerShell ($PROFILE).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$RepoRawUrl = "https://raw.githubusercontent.com/91wallace/dirnav/main"
$InstallDir = "$env:LOCALAPPDATA\Programs\dirnav"

Write-Host "==> Instalando dirnav no Windows..." -ForegroundColor Cyan

# 1. Verifica Python
$pythonCmd = $null
if (Get-Command "python" -ErrorAction SilentlyContinue) {
    $pythonCmd = "python"
} elseif (Get-Command "py" -ErrorAction SilentlyContinue) {
    $pythonCmd = "py"
} else {
    Write-Error "Python 3 nao foi encontrado no PATH. Por favor, instale o Python 3 antes de continuar."
    exit 1
}

# 2. Cria diretorio de destino
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

# 3. Copia ou baixa o arquivo 'dirnav'
$localDirnav = Join-Path $PSScriptRoot "dirnav"
$targetScript = Join-Path $InstallDir "dirnav.py"

if (Test-Path $localDirnav) {
    Copy-Item -Path $localDirnav -Destination $targetScript -Force
} else {
    Write-Host "Baixando dirnav de $RepoRawUrl/dirnav..." -ForegroundColor Gray
    curl.exe -fsSL "$RepoRawUrl/dirnav" -o "$targetScript"
}

# 4. Cria wrapper executavel 'dirnav.cmd' para permitir chamar 'dirnav' no terminal
$cmdLauncher = Join-Path $InstallDir "dirnav.cmd"
$cmdContent = "@echo off`r`n`"$pythonCmd`" `"$targetScript`" %*`r`n"
[System.IO.File]::WriteAllText($cmdLauncher, $cmdContent)

# 5. Adiciona InstallDir ao PATH do usuario caso nao esteja
$userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($userPath -split ';' -notcontains $InstallDir) {
    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    $env:Path = "$InstallDir;$env:Path"
    Write-Host "[✓] Adicionado ao PATH do usuario: $InstallDir" -ForegroundColor Green
} else {
    Write-Host "[i] $InstallDir ja esta no PATH." -ForegroundColor Gray
}

# 6. Configura o perfil do PowerShell ($PROFILE)
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
}

$integrationBlock = @'

# Dirnav shell integration
function dn {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string]$Path
    )

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        if ($Path) {
            dirnav --cwd-file="$tmp" "$Path"
        } else {
            dirnav --cwd-file="$tmp"
        }
        if (Test-Path $tmp) {
            $target = (Get-Content $tmp -Raw -Encoding utf8).Trim()
            if ($target -and (Test-Path $target)) {
                Set-Location $target
            }
        }
    } finally {
        if (Test-Path $tmp) {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
Set-Alias -Name dirnav -Value dn -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name cc -Value dn -Option AllScope -ErrorAction SilentlyContinue
'@

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -match "(?ms)# Dirnav shell integration.*?(?=\r?\n\r?\n|$)") {
    # Substitui bloco antigo
    $cleanProfile = [System.Text.RegularExpressions.Regex]::Replace($profileContent, "(?ms)# Dirnav shell integration\s+function (?:cc|dn)\b.*?(?=\r?\n#|\z)", "")
    $cleanProfile = $cleanProfile.Trim() + "`r`n" + $integrationBlock
    Set-Content -Path $PROFILE -Value $cleanProfile.Trim() -Encoding utf8
    Write-Host "[✓] Integracao atualizada no perfil do PowerShell: $PROFILE" -ForegroundColor Green
} else {
    Add-Content -Path $PROFILE -Value $integrationBlock
    Write-Host "[✓] Integracao adicionada ao perfil do PowerShell: $PROFILE" -ForegroundColor Green
}

Write-Host ""
Write-Host "Instalacao concluida com sucesso!" -ForegroundColor Green
Write-Host "Para utilizar na sessao atual:" -ForegroundColor Yellow
Write-Host "  . `$PROFILE" -ForegroundColor Cyan
Write-Host "Comando: dn (ou dirnav)" -ForegroundColor Yellow
