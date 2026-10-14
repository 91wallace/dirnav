<#
.SYNOPSIS
    Script de desinstalacao do dirnav no Windows (PowerShell)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

$InstallDir = "$env:LOCALAPPDATA\Programs\dirnav"

Write-Host "==> Desinstalando dirnav do Windows..." -ForegroundColor Cyan

# 1. Remove diretorio de instalacao
if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force -Path $InstallDir
    Write-Host "[✓] Removido diretorio: $InstallDir" -ForegroundColor Green
}

# 2. Remove do PATH do usuario
$userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($userPath) {
    $paths = ($userPath -split ';') | Where-Object { $_ -ne $InstallDir -and $_ -ne "" }
    $newPath = $paths -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host "[✓] Removido do PATH do usuario." -ForegroundColor Green
}

# 3. Remove integracao do $PROFILE
if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw
    if ($content -match "function cc\b") {
        # Substitui bloco de integracao do dirnav
        $newProfile = [System.Text.RegularExpressions.Regex]::Replace($content, "(?ms)# Dirnav shell integration\s+function cc\s*\{.*?\n\}\r?\n?", "")
        Set-Content -Path $PROFILE -Value $newProfile.Trim() -Encoding utf8
        Write-Host "[✓] Integracao removida de $PROFILE" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Desinstalacao concluida!" -ForegroundColor Green
