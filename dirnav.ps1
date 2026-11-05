# Dirnav PowerShell integration
function dn {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string]$Path
    )

    $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "dirnav-cwd-$([guid]::NewGuid().ToString('N')).tmp")
    try {
        $installedScript = Join-Path $env:LOCALAPPDATA "Programs\dirnav\dirnav.py"
        $localScript = Join-Path $PSScriptRoot "dirnav"
        $scriptToRun = if (Test-Path -LiteralPath $localScript) { $localScript } elseif (Test-Path -LiteralPath $installedScript) { $installedScript } else { $null }

        $pyExe = if (Get-Command "py" -ErrorAction SilentlyContinue) { "py" } else { "python" }

        if ($scriptToRun) {
            if ($Path) {
                & $pyExe "$scriptToRun" --cwd-file "$tmp" "$Path"
            } else {
                & $pyExe "$scriptToRun" --cwd-file "$tmp"
            }
        } else {
            if ($Path) {
                dirnav.cmd --cwd-file "$tmp" "$Path"
            } else {
                dirnav.cmd --cwd-file "$tmp"
            }
        }

        if (Test-Path -LiteralPath $tmp) {
            $raw = [System.IO.File]::ReadAllText($tmp, [System.Text.Encoding]::UTF8)
            if ($null -ne $raw) {
                $target = $raw.Trim()
                if ($target -and (Test-Path -LiteralPath $target -PathType Container)) {
                    Set-Location -LiteralPath $target
                }
            }
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

function cc {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string]$Path
    )
    if ($Path) {
        dn $Path
    } else {
        dn
    }
}

Set-Alias -Name dirnav -Value dn -Option AllScope -Force -ErrorAction SilentlyContinue
# END Dirnav PowerShell integration
