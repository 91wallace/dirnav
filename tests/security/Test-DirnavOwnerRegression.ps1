[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.Schema -ne 'dirnav-adversarial-v1') { throw 'Unsupported manifest schema.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if ($identity.User.Value -ne $manifest.StageOwnerSid) { throw 'Run owner regression as the preparing identity.' }
$projectRoot = [IO.Path]::GetFullPath([string]$manifest.ProjectRoot)
$pythonLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
if ($pythonLauncher) { $pythonExecutable=$pythonLauncher.Source; $pythonPrefix=@('-3') }
else {
    $pythonLauncher = Get-Command python.exe -ErrorAction SilentlyContinue
    if (-not $pythonLauncher) { throw 'Python 3 was not found (py.exe or python.exe required).' }
    $pythonExecutable=$pythonLauncher.Source; $pythonPrefix=@()
}
$pytestSuites = @(
    [pscustomobject]@{ Name='PythonFull'; Args=@('-m','pytest','-q','-rs') },
    [pscustomobject]@{ Name='CmdIntegration'; Args=@('-m','pytest','-q','tests/shell/test_cmd.py') }
)
$results = [Collections.Generic.List[object]]::new()
$savedLocation = Get-Location
try {
    Set-Location -LiteralPath $projectRoot
    foreach ($suite in $pytestSuites) {
        $arguments = $suite.Args
        $output = @(& $pythonExecutable @pythonPrefix @arguments 2>&1)
        $exitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Output $_ }
        $summary = ($output | Where-Object { $_ -match '\d+ passed|\d+ failed|\d+ skipped' } | Select-Object -Last 1) -join ''
        $results.Add([pscustomobject]@{ Name=$suite.Name; Status=$(if($exitCode -eq 0){'PASS'}else{'FAIL'}); ExitCode=$exitCode; Summary=$summary })
    }
    $ps51 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $ps51) {
        $output = @(& $ps51 -NoLogo -NoProfile -File (Join-Path $projectRoot 'tests\shell\Dirnav.Tests.ps1') 2>&1)
        $exitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Output $_ }
        $summary = ($output | Where-Object { $_ -match 'Resumo PowerShell Tests:' } | Select-Object -Last 1) -join ''
        $results.Add([pscustomobject]@{ Name='WindowsPowerShell51'; Status=$(if($exitCode -eq 0){'PASS'}else{'FAIL'}); ExitCode=$exitCode; Summary=$summary })
    } else {
        $results.Add([pscustomobject]@{ Name='WindowsPowerShell51'; Status='BLOCKED'; ExitCode=$null; Summary='powershell.exe unavailable' })
    }
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        $output = @(& $pwsh.Source -NoLogo -NoProfile -File (Join-Path $projectRoot 'tests\shell\Dirnav.Tests.ps1') 2>&1)
        $exitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Output $_ }
        $summary = ($output | Where-Object { $_ -match 'Resumo PowerShell Tests:' } | Select-Object -Last 1) -join ''
        $results.Add([pscustomobject]@{ Name='PowerShell7'; Status=$(if($exitCode -eq 0){'PASS'}else{'FAIL'}); ExitCode=$exitCode; Summary=$summary })
    } else {
        $results.Add([pscustomobject]@{ Name='PowerShell7'; Status='BLOCKED'; ExitCode=$null; Summary='pwsh unavailable; not installed by this script' })
    }
} finally {
    Set-Location $savedLocation
}

$overall = if (@($results | Where-Object Status -ne 'PASS').Count -eq 0) { 'PASS' } elseif (@($results | Where-Object Status -eq 'FAIL').Count) { 'FAIL' } else { 'BLOCKED' }
$report = [pscustomobject]@{ Schema='dirnav-owner-regression-v1'; RunId=$manifest.RunId; ObservedUtc=[DateTime]::UtcNow.ToString('o'); OwnerSid=$identity.User.Value; Overall=$overall; Suites=@($results) }
$evidenceDir = Join-Path $projectRoot 'docs\audit\results'
if (-not (Test-Path -LiteralPath $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir | Out-Null }
$evidencePath = Join-Path $evidenceDir "f15-owner-regression-$($manifest.RunId).json"
if (Test-Path -LiteralPath $evidencePath) { throw "Evidence path already exists: $evidencePath" }
[IO.File]::WriteAllText($evidencePath,($report | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
$report | ConvertTo-Json -Depth 6
"EVIDENCE=$evidencePath"
if ($overall -ne 'PASS') { exit 1 }
