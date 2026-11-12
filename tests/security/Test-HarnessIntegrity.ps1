[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'DirnavAudit.Native.psm1') -Force
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('dirnav-f15-unit-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$passed=0
function Assert-True([bool]$Condition,[string]$Message) { if(-not $Condition){throw $Message} }
function Assert-Throws([scriptblock]$Action,[string]$Message) { $threw=$false;try{& $Action}catch{$threw=$true};if(-not $threw){throw $Message} }
try {
    $pf=Join-Path $fixture 'ProgramFiles'
    $runId=[guid]::NewGuid().ToString('N')
    $stage=Join-Path $pf "DirnavAudit-$runId"
    $root=Join-Path $stage 'Root'
    $results=Join-Path $stage 'Results'
    $secure=Join-Path $root ('dirnav-cmd-'+[guid]::NewGuid().ToString('N'))
    $project=Join-Path $fixture 'repo'
    [void][IO.Directory]::CreateDirectory($stage);[void][IO.Directory]::CreateDirectory($project)
    $names=@('read.cmd','edit.cmd','replace.cmd','delete.cmd','rename.cmd','dacl.cmd','owner.cmd')
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $sddl="D:P(A;;FA;;;$sid)"
    $items=@(foreach($name in $names){[pscustomobject]@{Name=$name;Path=(Join-Path $secure $name);Sha256=('0'*64);Sddl=$sddl}})
    $manifest=[pscustomobject]@{
        Schema='dirnav-adversarial-v1';RunId=$runId;StageRoot=$stage;StageOwnerSid=$sid;TestUser='DirnavTestUser';TestUserSid='S-1-5-21-1-2-3-1001'
        ProjectRoot=$project;Root=$root;RootSddl=$sddl;ResultsDirectory=$results;SecureDirectory=$secure;SecureDirectorySddl=$sddl
        Target=(Join-Path $root 'selected & ^ % ! (ç)');ResultFile=(Join-Path $results 'adversarial.json');ReplaceSource=(Join-Path $results 'replacement-payload.cmd')
        OwnerRegressionPath=(Join-Path $project "docs\audit\results\f15-owner-regression-$runId.json");Items=$items
    }
    $manifestPath=Join-Path $stage 'manifest.json'
    $null=[IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    $loaded=Read-DirnavAuditManifest -ManifestPath $manifestPath -ProgramFilesRoot $pf
    Assert-True ($loaded.Manifest.RunId -eq $runId) 'valid manifest rejected';$passed++

    Assert-Throws { Read-DirnavAuditManifest -ManifestPath (Join-Path $stage 'missing.json') -ProgramFilesRoot $pf } 'missing manifest accepted';$passed++
    $tampered=$manifest|Select-Object *;$tampered.ResultFile=Join-Path $fixture 'outside.json'
    $null=[IO.File]::WriteAllText($manifestPath,($tampered|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    Assert-Throws { Read-DirnavAuditManifest -ManifestPath $manifestPath -ProgramFilesRoot $pf } 'adulterated manifest accepted';$passed++
    $null=[IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))

    $evidence=Join-Path $fixture 'evidence.json'
    $json=[pscustomobject]@{Schema='dirnav-f15-final-v1';RunId=$runId}|ConvertTo-Json -Compress
    Assert-True (Write-DirnavAuditEvidenceExclusive -Path $evidence -Json $json) 'first exclusive evidence write failed';$passed++
    Assert-Throws { Write-DirnavAuditEvidenceExclusive -Path $evidence -Json $json } 'duplicate evidence was overwritten';$passed++
    Assert-True ([IO.File]::ReadAllText($evidence) -eq $json) 'duplicate evidence attempt changed original evidence';$passed++

    $missingParentPath=Join-Path (Join-Path $fixture 'absent') 'final.json'
    Assert-Throws { Write-DirnavAuditEvidenceExclusive -Path $missingParentPath -Json $json } 'write failure unexpectedly succeeded';$passed++
    $cleanupCalled=$false
    Assert-Throws { Invoke-DirnavAuditCleanupAfterPersistence -EvidencePath (Join-Path $fixture 'absent-evidence.json') -RunId $runId -CleanupAction {$script:cleanupCalled=$true} } 'cleanup allowed without persisted evidence';$passed++
    Assert-True (-not $cleanupCalled) 'cleanup action ran before evidence persistence';$passed++

    $interrupted=$false
    Assert-Throws { Invoke-DirnavAuditCleanupAfterPersistence -EvidencePath $evidence -RunId $runId -CleanupAction {throw 'injected cleanup interruption'} } 'cleanup interruption did not propagate';$passed++
    $interruptedEvidence=Get-Content -LiteralPath $evidence -Raw|ConvertFrom-Json
    Assert-True ($interruptedEvidence.RunId -eq $runId) 'evidence missing after interrupted cleanup';$passed++
    $cleanupCalled=$false
    Assert-True (Invoke-DirnavAuditCleanupAfterPersistence -EvidencePath $evidence -RunId $runId -CleanupAction {$script:cleanupCalled=$true}) 'cleanup transaction failed';$passed++
    Assert-True $cleanupCalled 'cleanup action was not invoked after verified evidence';$passed++

    $expectedDacl="O:$sid`G:SY`D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FA;;;$sid)"
    $restoredDacl="O:$sid`G:SY`D:PAI(A;;FA;;;SY)(A;;FA;;;BA)(A;;FA;;;$sid)"
    Assert-True (Test-DirnavAuditSecurityDescriptorEquivalent -ActualSddl $restoredDacl -ExpectedSddl $expectedDacl) 'protected DACL with Windows AI control flag was rejected';$passed++
    $tamperedDacl=$restoredDacl.Replace('(A;;FA;;;BA)','(A;;FA;;;BA)(A;;FA;;;WD)')
    Assert-True (-not (Test-DirnavAuditSecurityDescriptorEquivalent -ActualSddl $tamperedDacl -ExpectedSddl $expectedDacl)) 'unexpected ACE accepted by descriptor comparison';$passed++

    $badItems=$manifest|Select-Object *;$badItems.Items=@($manifest.Items|Select-Object -Skip 1)
    $null=[IO.File]::WriteAllText($manifestPath,($badItems|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    Assert-Throws { Read-DirnavAuditManifest -ManifestPath $manifestPath -ProgramFilesRoot $pf } 'manifest with missing artifact record accepted';$passed++
    "HARNESS_INTEGRITY_PASS=$passed"
} finally {
    if (Test-Path -LiteralPath $fixture) { [IO.Directory]::Delete($fixture,$true) }
}
