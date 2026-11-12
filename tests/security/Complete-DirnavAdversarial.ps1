[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DirnavAudit.Native.psm1') -Force
$expectedProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$loaded = Read-DirnavAuditManifest -ManifestPath $ManifestPath -ExpectedProjectRoot $expectedProjectRoot
$manifest = $loaded.Manifest
$manifestFull = $loaded.Path
$validated = $loaded.Paths
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if ($identity.User.Value -ne $manifest.StageOwnerSid) { throw 'Run finalization as the preparing owner identity.' }
$marker = Join-Path $validated.Stage '.dirnav-audit-marker'
Assert-DirnavNoReparseChain -Path $marker | Out-Null
if (-not (Test-Path -LiteralPath $marker -PathType Leaf) -or
    (Get-Content -LiteralPath $marker -Raw -Encoding Ascii) -ne "$($manifest.RunId)|$($manifest.StageOwnerSid)|$($manifest.TestUserSid)") {
    throw 'Audit marker is absent or does not match; no cleanup performed.'
}
$adversarial = $null
$adversarialEvidenceError = $null
$outcomes = [Collections.Generic.List[object]]::new()
$integrity = [Collections.Generic.List[object]]::new()
$secureDirectoryIntegrity = 'BLOCKED'
$regression = $null
$profileAfter = @()
$profileStatus = 'INSPECTION_BLOCKED'
$attemptNames = @{
    Edit='EditBatch'; Replace='ReplaceBatch'; Delete='DeleteBatch'; Rename='RenameBatch'; CreateFile='CreateFileInProtectedDirectory'
    ChangeDacl='ChangeBatchDacl'; ChangeOwner='ChangeBatchOwner'; ChangeSecureDirectoryDacl='ChangeSecureDirectoryDacl'; ChangeSecureDirectoryOwner='ChangeSecureDirectoryOwner'
}
$scopeRights = @{
    Edit=@('BatchDacl:edit.cmd','WriteData'); Replace=@('BatchDacl:replace.cmd','WriteData'); Delete=@('BatchDacl:delete.cmd','Delete')
    Rename=@('BatchDacl:rename.cmd','Delete'); CreateFile=@('SecureDirectoryDacl','CreateFile'); ChangeDacl=@('BatchDacl:dacl.cmd','WriteDacl')
    ChangeOwner=@('BatchDacl:owner.cmd','WriteOwner'); ChangeSecureDirectoryDacl=@('SecureDirectoryDacl','WriteDacl')
    ChangeSecureDirectoryOwner=@('SecureDirectoryDacl','WriteOwner')
}
function Get-Attempt([string]$Name) {
    if ($null -eq $script:adversarial) { return $null }
    $matches = @($script:adversarial.Attempts | Where-Object { $_.Name -eq $Name })
    if ($matches.Count -ne 1) { return $null }
    return $matches[0]
}
function Get-AccessDenied([string]$Scope,[string]$Right) {
    if ($null -eq $script:adversarial) { return $false }
    $matches = @($script:adversarial.EffectiveAccessChecks | Where-Object { $_.Scope -eq $Scope -and $_.Right -eq $Right })
    return ($matches.Count -eq 1 -and $matches[0].Allowed -eq $false)
}
function Add-BlockedOutcomes {
    foreach ($criterion in $script:attemptNames.Keys) {
        $script:outcomes.Add([pscustomobject]@{ Criterion=$criterion; Status='BLOCKED'; ActualAttempt=$null; AccessCheckDenied=$false; Detail='Adversarial result evidence missing or invalid.' })
    }
}

$resultPath = [string]$manifest.ResultFile
Assert-DirnavNoReparseChain -Path $resultPath | Out-Null
if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
    Assert-DirnavNoReparseChain -Path $resultPath | Out-Null
    if ((Get-Item -LiteralPath $resultPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Adversarial result is a reparse point; no cleanup performed.' }
    if ((Get-Item -LiteralPath $resultPath).Length -eq 0) { $adversarialEvidenceError='Adversarial result file exists but is empty; no token execution evidence was produced.' }
    else {
        try {
            $candidate = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            if ($candidate.Schema -eq 'dirnav-adversarial-results-v1' -and $candidate.RunId -eq $manifest.RunId -and
                $candidate.Identity.Sid -eq $manifest.TestUserSid -and -not $candidate.Identity.IsAdministrator) { $adversarial = $candidate }
            else { $adversarialEvidenceError='Adversarial result identity, schema, or RunId did not match the manifest.' }
        } catch { $adversarialEvidenceError="Adversarial result JSON could not be parsed: $($_.Exception.Message)" }
    }
}
if ($null -eq $adversarial) { Add-BlockedOutcomes }
else {
    $ancestorAccess = @($adversarial.AncestorAccess | Where-Object { $_.Result -eq 'ACCESSIBLE' })
    foreach ($criterion in $attemptNames.Keys) {
        $attempt = Get-Attempt $attemptNames[$criterion]
        $pair = $scopeRights[$criterion]
        $aclDenied = Get-AccessDenied $pair[0] $pair[1]
        $attemptDenied = ($null -ne $attempt -and $attempt.Result -eq 'DENIED_OR_ERROR' -and $attempt.Win32Code -eq 5)
        $ancestorsReachable = ($ancestorAccess.Count -eq @($adversarial.AncestorAccess).Count -and @($adversarial.AncestorAccess).Count -ge 4)
        $status = if ($null -eq $attempt -or $null -eq $attempt.Win32Code -or -not $aclDenied -or -not $ancestorsReachable) { 'BLOCKED' } elseif ($attemptDenied) { 'PASS' } else { 'FAIL' }
        $outcomes.Add([pscustomobject]@{ Criterion=$criterion; Status=$status; ActualAttempt=$attempt; AccessCheckDenied=$aclDenied; AncestorsReachable=$ancestorsReachable; Detail='PASS requires real access-denied result, matching AccessCheck denial, and accessible ancestors.' })
    }
}

foreach ($item in $validated.Items) {
    $state='BLOCKED'; $details=@()
    if ($null -ne $adversarial) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) { $state='FAIL'; $details += 'artifact missing after adversarial attempts' }
        elseif ((Get-Item -LiteralPath $item.Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { $state='FAIL'; $details += 'artifact became a reparse point' }
        else {
            $hash=(Get-FileHash -LiteralPath $item.Path -Algorithm SHA256).Hash
            $acl=Get-DirnavAuditAclSnapshot -Path $item.Path
            $state='PASS'
            if ($hash -ne $item.Sha256) { $state='FAIL'; $details += 'content hash changed' }
            if (-not $acl.Protected -or $acl.OwnerSid -ne $manifest.StageOwnerSid -or $acl.Aces.Count -ne 3 -or $acl.Sddl -ne $item.Sddl) { $state='FAIL'; $details += 'owner or protected DACL changed' }
        }
    }
    $integrity.Add([pscustomobject]@{ Name=$item.Name; Status=$state; Details=($details -join '; '); ExpectedSha256=$item.Sha256 })
}
if (Test-Path -LiteralPath $manifest.SecureDirectory -PathType Container) {
    if ((Get-Item -LiteralPath $manifest.SecureDirectory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { $secureDirectoryIntegrity='FAIL' }
    else {
        $dirAcl=Get-DirnavAuditAclSnapshot -Path $manifest.SecureDirectory
        $secureDirectoryIntegrity=if($dirAcl.Protected -and $dirAcl.OwnerSid -eq $manifest.StageOwnerSid -and $dirAcl.Sddl -eq $manifest.SecureDirectorySddl){'PASS'}else{'FAIL'}
    }
} elseif ($null -ne $adversarial) { $secureDirectoryIntegrity='FAIL' }

if (Test-Path -LiteralPath $manifest.OwnerRegressionPath -PathType Leaf) {
    Assert-DirnavNoReparseChain -Path $manifest.OwnerRegressionPath | Out-Null
    if ((Get-Item -LiteralPath $manifest.OwnerRegressionPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Owner regression evidence is a reparse point; no cleanup performed.' }
    $regression = Get-Content -LiteralPath $manifest.OwnerRegressionPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    if ($regression.Schema -ne 'dirnav-owner-regression-v1' -or $regression.RunId -ne $manifest.RunId -or $regression.OwnerSid -ne $manifest.StageOwnerSid) { $regression=$null }
}
$readAttempt = if ($null -ne $adversarial) { $matches=@($adversarial.Attempts | Where-Object Name -eq 'ReadBatch'); if ($matches.Count -eq 1) { $matches[0] } else { $null } } else { $null }
$readStatus = if ($null -eq $readAttempt) { 'BLOCKED' } elseif ($readAttempt.Result -eq 'UNEXPECTED_SUCCESS') { 'READABLE' } elseif ($readAttempt.Win32Code -eq 5) { 'DENIED' } else { 'ERROR' }
try {
    $profileAfter=@(Get-CimInstance Win32_UserProfile -Filter "SID='$($manifest.TestUserSid)'" -ErrorAction Stop | Select-Object SID,LocalPath,Loaded,Special)
    $profileStatus=if($profileAfter.Count -eq 0){'NONE'}elseif(@($manifest.TestUserProfileBefore).Count){'PREEXISTING_LEFT_INTACT'}else{'CREATED_DURING_RUN_LEFT_INTACT'}
} catch { $profileAfter=@(); $profileStatus='INSPECTION_BLOCKED' }
$criticalPass = ($null -ne $adversarial -and $outcomes.Count -eq 9 -and @($outcomes | Where-Object Status -ne 'PASS').Count -eq 0 -and @($integrity | Where-Object Status -ne 'PASS').Count -eq 0 -and $secureDirectoryIntegrity -eq 'PASS')
$regressionPass = ($null -ne $regression -and $regression.Overall -eq 'PASS')
$overall = if ($criticalPass -and $regressionPass) { 'PASS' } elseif ($null -eq $adversarial -or $null -eq $regression) { 'BLOCKED' } else { 'FAIL' }
$evidenceDir=Join-Path ([IO.Path]::GetFullPath([string]$manifest.ProjectRoot)) 'docs\audit\results'
$evidencePath=Join-Path $evidenceDir "f15-adversarial-$($manifest.RunId).json"
Assert-DirnavNoReparseChain -Path $evidenceDir | Out-Null
Assert-DirnavNoReparseChain -Path $evidencePath | Out-Null
if (-not (Test-Path -LiteralPath $evidenceDir -PathType Container)) { New-Item -ItemType Directory -Path $evidenceDir -ErrorAction Stop | Out-Null }
if ((Get-Item -LiteralPath $evidenceDir -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Evidence directory is a reparse point; no cleanup performed.' }
$report = [pscustomobject]@{
    Schema='dirnav-f15-final-v1'; RunId=$manifest.RunId; ObservedUtc=[DateTime]::UtcNow.ToString('o'); OwnerSid=$identity.User.Value
    TestUser=$manifest.TestUser; TestUserSid=$manifest.TestUserSid; Overall=$overall; WriteBoundaryCriteria=@($outcomes)
    ReadConfidentiality=[pscustomobject]@{ Status=$readStatus; Attempt=$readAttempt; PolicyDecision='Review separately; this result is not included in write-boundary PASS.' }
    SecureDirectoryIntegrity=$secureDirectoryIntegrity; ArtifactIntegrity=@($integrity); OwnerRegression=$regression
    DirectAdversaryEvidence=$adversarial; AdversarialEvidenceError=$adversarialEvidenceError
    TestUserProfile=[pscustomobject]@{ Before=@($manifest.TestUserProfileBefore); After=$profileAfter; Status=$profileStatus; CleanupPolicy='Account and profile are never deleted by this harness.' }
    Cleanup=[pscustomobject]@{ Status='EVIDENCE_PERSISTED_BEFORE_CLEANUP'; Detail='Cleanup is gated on rereading this run-specific evidence; command output records the cleanup result.' }
}
$json=$report | ConvertTo-Json -Depth 14
$null = Write-DirnavAuditEvidenceExclusive -Path $evidencePath -Json $json
# Evidence is now durable and was re-read/parsed. Cleanup is deliberately outside finally.
$cleanupScript=Join-Path $PSScriptRoot 'Remove-DirnavAdversarialArtifacts.ps1'
try {
    $null = Invoke-DirnavAuditCleanupAfterPersistence -EvidencePath $evidencePath -RunId $manifest.RunId -CleanupAction { & $cleanupScript -ManifestPath $manifestFull }
    "EVIDENCE=$evidencePath"
    'CLEANUP=PASS'
} catch {
    Write-Error "Evidence persisted at '$evidencePath'; cleanup stopped safely: $($_.Exception.Message)"
    throw
}
