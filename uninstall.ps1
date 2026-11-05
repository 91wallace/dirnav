<#
.SYNOPSIS
    Script de desinstalacao do dirnav no Windows (PowerShell 5.1 / PowerShell 7+)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

$InstallDir = if ($env:DIRNAV_INSTALL_DIR) { $env:DIRNAV_INSTALL_DIR } else { "$env:LOCALAPPDATA\Programs\dirnav" }

Write-Host "==> Desinstalando dirnav do Windows..." -ForegroundColor Cyan

# 1. Remove diretorio de instalacao
if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -Recurse -Force -LiteralPath $InstallDir
    Write-Host "[OK] Removido diretorio: $InstallDir" -ForegroundColor Green
}

# 2. Remove do PATH do usuario (apenas se nao for teste isolado)
if (-not $env:DIRNAV_SKIP_PATH) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if ($userPath) {
        $paths = ($userPath -split ';') | Where-Object { $_ -ne $InstallDir -and $_ -ne "" }
        $newPath = $paths -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
        Write-Host "[OK] Removido do PATH do usuario." -ForegroundColor Green
    }
}

# 3. Remove integracao e aliases orfaos dos perfis do PowerShell (Bug Critico 5 resolvido)
$targetProfiles = @()
if ($env:DIRNAV_TEST_PROFILE) {
    $targetProfiles += $env:DIRNAV_TEST_PROFILE
} else {
    $docs = [Environment]::GetFolderPath("MyDocuments")
    if ($docs) {
        $targetProfiles += Join-Path $docs "PowerShell\Microsoft.PowerShell_profile.ps1"
        $targetProfiles += Join-Path $docs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    }
    if ($PROFILE -and ($targetProfiles -notcontains $PROFILE)) {
        $targetProfiles += $PROFILE
    }
}

$pattern = "(?ms)# Dirnav shell integration.*?# END Dirnav shell integration\r?\n?|# Dirnav shell integration\s+function \w+\b.*?(?:Set-Alias -Name cc[^\r\n]*\r?\n?|Set-Alias -Name dirnav[^\r\n]*\r?\n?)+"

foreach ($prof in ($targetProfiles | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $prof) {
        $content = Get-Content -LiteralPath $prof -Raw -ErrorAction SilentlyContinue
        if ($content -and ($content -match "# Dirnav shell integration" -or $content -match "dirnav\.cmd --cwd-file" -or $content -match "dirnav --cwd-file")) {
            $newProfile = [System.Text.RegularExpressions.Regex]::Replace($content, $pattern, "")
            # Limpa tambem eventuais aliases orfaos de versoes anteriores
            $newProfile = [System.Text.RegularExpressions.Regex]::Replace($newProfile, "(?m)^Set-Alias -Name (dirnav|cc) -Value \w+ -Option AllScope.*?\r?\n?", "")
            Set-Content -LiteralPath $prof -Value $newProfile.Trim() -Encoding utf8
            Write-Host "[OK] Integracao removida de $prof" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Desinstalacao concluida!" -ForegroundColor Green
