# Dirnav PowerShell integration
function cc {
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
}
