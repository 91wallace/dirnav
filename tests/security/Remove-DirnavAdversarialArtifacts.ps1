[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DirnavAudit.Native.psm1') -Force
$expectedProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$loaded = Read-DirnavAuditManifest -ManifestPath $ManifestPath -ExpectedProjectRoot $expectedProjectRoot
$manifest = $loaded.Manifest
$manifestPath = $loaded.Path
$validated = $loaded.Paths
$stage = $validated.Stage
$root = $validated.Root
$secure = $validated.Secure
$results = $validated.Results
$target = $validated.Target
$finalEvidence = Join-Path ([IO.Path]::GetFullPath([string]$manifest.ProjectRoot)) "docs\audit\results\f15-adversarial-$($manifest.RunId).json"
Assert-DirnavNoReparseChain -Path $finalEvidence | Out-Null
if (-not (Test-Path -LiteralPath $finalEvidence -PathType Leaf) -or (Get-Item -LiteralPath $finalEvidence -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Final evidence must be persisted before cleanup; no artifacts removed.'
}
$finalData = Get-Content -LiteralPath $finalEvidence -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
if ($finalData.Schema -ne 'dirnav-f15-final-v1' -or $finalData.RunId -ne $manifest.RunId) { throw 'Final evidence does not match this run; refusing cleanup.' }
$marker = Join-Path $stage '.dirnav-audit-marker'
$expectedMarker = "$($manifest.RunId)|$($manifest.StageOwnerSid)|$($manifest.TestUserSid)"
if (-not (Test-Path -LiteralPath $marker -PathType Leaf) -or (Get-Content -LiteralPath $marker -Raw) -ne $expectedMarker) {
    throw 'Audit marker does not match; refusing cleanup.'
}
$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if ($currentSid -ne $manifest.StageOwnerSid) { throw 'Run cleanup as the owner identity that prepared the staging directory.' }

function Assert-NotReparse([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unexpected reparse point at $Path; no recursive cleanup attempted." }
}

foreach ($path in @($stage,$root,$secure,$results,$target)) { Assert-NotReparse $path }
foreach ($path in @($stage,$root,$secure,$results,$target,$finalEvidence)) { Assert-DirnavNoReparseChain -Path $path | Out-Null }
foreach ($path in @($root,$results)) {
    $parent = Split-Path -Parent $path
    if (-not $parent.Equals($stage,[StringComparison]::OrdinalIgnoreCase)) { throw "Unexpected cleanup parent for $path" }
}
if (-not (Split-Path -Parent $secure).Equals($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected secure-directory location.' }
if (-not $target.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected target location.' }

$knownBatchNames = @($manifest.Items | ForEach-Object { [string]$_.Name })
$knownBatchNames += @('attacker-created.cmd')
foreach ($name in @($manifest.Items | ForEach-Object { [string]$_.Name })) { $knownBatchNames += "$name.renamed" }
if (Test-Path -LiteralPath $secure) {
    foreach ($item in $manifest.Items) {
        foreach ($candidate in @([string]$item.Path,([string]$item.Path+'.renamed'))) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                Assert-NotReparse $candidate
                [DirnavAuditNative]::RestoreOwnerAndDaclFromSddl($candidate,[string]$item.Sddl)
                $restored=Get-DirnavAuditAclSnapshot -Path $candidate
                if (-not $restored.Protected -or $restored.OwnerSid -ne $manifest.StageOwnerSid -or $restored.Aces.Count -ne 3 -or
                    @($restored.Aces | Where-Object { $_.Sid -notin @($manifest.StageOwnerSid,'S-1-5-18','S-1-5-32-544') -or $_.Type -ne 'Allow' -or $_.Inherited }).Count -or
                    -not (Test-DirnavAuditSecurityDescriptorEquivalent -ActualSddl $restored.Sddl -ExpectedSddl ([string]$item.Sddl))) {
                    throw "Could not restore the original test-artifact security descriptor: $candidate"
                }
            }
        }
    }
    [DirnavAuditNative]::RestoreOwnerAndDaclFromSddl($secure,[string]$manifest.SecureDirectorySddl)
    $directoryAcl=Get-DirnavAuditAclSnapshot -Path $secure
    if (-not $directoryAcl.Protected -or $directoryAcl.OwnerSid -ne $manifest.StageOwnerSid -or $directoryAcl.Aces.Count -ne 3 -or
        @($directoryAcl.Aces | Where-Object { $_.Sid -notin @($manifest.StageOwnerSid,'S-1-5-18','S-1-5-32-544') -or $_.Type -ne 'Allow' -or $_.Inherited }).Count -or
        -not (Test-DirnavAuditSecurityDescriptorEquivalent -ActualSddl $directoryAcl.Sddl -ExpectedSddl ([string]$manifest.SecureDirectorySddl))) {
        throw 'Could not restore the secure test-directory descriptor.'
    }
    $entries = @(Get-ChildItem -LiteralPath $secure -Force)
    $unexpected = @($entries | Where-Object { $_.Name -notin $knownBatchNames })
    if ($unexpected) { throw "Unexpected item in secure artifact directory; preserved for manual review: $($unexpected.Name -join ', ')" }
    foreach ($entry in $entries) {
        Assert-NotReparse $entry.FullName
        if ($entry.PSIsContainer) { throw "Unexpected directory in secure artifact directory: $($entry.FullName)" }
        [IO.File]::Delete($entry.FullName)
    }
    [IO.Directory]::Delete($secure,$false)
}

$knownResultNames = @('adversarial.json','replacement-payload.cmd')
if (Test-Path -LiteralPath $results) {
    Assert-NotReparse $results
    $entries = @(Get-ChildItem -LiteralPath $results -Force)
    $unexpected = @($entries | Where-Object { $_.Name -notin $knownResultNames })
    if ($unexpected) { throw "Unexpected item in results directory; preserved for manual review: $($unexpected.Name -join ', ')" }
    foreach ($entry in $entries) {
        Assert-NotReparse $entry.FullName
        if ($entry.PSIsContainer) { throw "Unexpected directory in results directory: $($entry.FullName)" }
        [IO.File]::Delete($entry.FullName)
    }
    [IO.Directory]::Delete($results,$false)
}
if (Test-Path -LiteralPath $target) { [IO.Directory]::Delete($target,$false) }

if (Test-Path -LiteralPath $root) {
    $entries = @(Get-ChildItem -LiteralPath $root -Force)
    if ($entries.Count) { throw "Unexpected residue under isolated Root: $($entries.Name -join ', ')" }
    [IO.Directory]::Delete($root,$false)
}

$knownStageFiles = @('DirnavAudit.Native.psm1','Invoke-DirnavAdversary.ps1','manifest.json','.dirnav-audit-marker')
$stageEntries = @(Get-ChildItem -LiteralPath $stage -Force)
$unexpectedStage = @($stageEntries | Where-Object { $_.Name -notin $knownStageFiles })
if ($unexpectedStage) { throw "Unexpected staging item; preserved for manual review: $($unexpectedStage.Name -join ', ')" }
foreach ($entry in $stageEntries) {
    Assert-NotReparse $entry.FullName
    if ($entry.PSIsContainer) { throw "Unexpected staging directory: $($entry.FullName)" }
    [IO.File]::Delete($entry.FullName)
}
[IO.Directory]::Delete($stage,$false)
if (Test-Path -LiteralPath $stage) { throw 'Staging directory remains after cleanup.' }
$receiptPath = [regex]::Replace($finalEvidence,'\.json$','.cleanup.json')
$receipt = [pscustomobject]@{
    Schema='dirnav-f15-cleanup-v1'; RunId=$manifest.RunId; ObservedUtc=[DateTime]::UtcNow.ToString('o')
    OwnerSid=$currentSid; TestUserSid=$manifest.TestUserSid; Status='PASS'
    RemovedStage=$stage; FinalEvidence=$finalEvidence; FinalEvidenceSha256=(Get-FileHash -LiteralPath $finalEvidence -Algorithm SHA256).Hash
    TestAccount='not removed by artifact cleanup'; TestProfile='not removed by artifact cleanup'
}
$null=Write-DirnavAuditEvidenceExclusive -Path $receiptPath -Json ($receipt|ConvertTo-Json -Depth 6)
Write-Output "CLEANUP_PASS RunId=$($manifest.RunId) AccountUntouched=$($manifest.TestUser) ProfileUntouched=True"
Write-Output "CLEANUP_EVIDENCE=$receiptPath"
