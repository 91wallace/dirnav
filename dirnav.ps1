# Dirnav PowerShell integration
function dn {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string]$Path
    )

    $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "dirnav-cwd-$([guid]::NewGuid().ToString('N')).tmp")
    try {
        $dirnavCmd = if (Get-Command "dirnav.cmd" -ErrorAction SilentlyContinue) { "dirnav.cmd" } elseif (Test-Path "$PSScriptRoot\dirnav") { "py `"$PSScriptRoot\dirnav`"" } else { "dirnav" }
        if ($Path) {
            if ($dirnavCmd.StartsWith("py ")) {
                py "$PSScriptRoot\dirnav" --cwd-file="$tmp" "$Path"
            } else {
                & $dirnavCmd --cwd-file="$tmp" "$Path"
            }
        } else {
            if ($dirnavCmd.StartsWith("py ")) {
                py "$PSScriptRoot\dirnav" --cwd-file="$tmp"
            } else {
                & $dirnavCmd --cwd-file="$tmp"
            }
        }
        if (Test-Path -LiteralPath $tmp) {
            $raw = Get-Content -LiteralPath $tmp -Raw -Encoding utf8 -ErrorAction SilentlyContinue
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
