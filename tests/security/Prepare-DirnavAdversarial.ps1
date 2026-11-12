[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$ConfirmTestAccount
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') { throw 'This harness requires Windows.' }
Import-Module (Join-Path $PSScriptRoot 'DirnavAudit.Native.psm1') -Force

$testUser = Get-LocalUser -Name 'DirnavTestUser' -ErrorAction SilentlyContinue
if (-not $testUser -or -not $testUser.Enabled) {
    throw 'Create/enable the standard local account DirnavTestUser manually first. This script never creates or removes accounts.'
}
if (-not $ConfirmTestAccount) { throw 'Inspect this account and rerun with -ConfirmTestAccount. Existing accounts are never assumed to belong to this test.' }
$usersGroup = Get-LocalGroup -SID 'S-1-5-32-545'
$adminsGroup = Get-LocalGroup -SID 'S-1-5-32-544'
$userMembers = @(Get-LocalGroupMember -Group $usersGroup.Name | Where-Object { $_.SID.Value -eq $testUser.SID.Value })
$adminMembers = @(Get-LocalGroupMember -Group $adminsGroup.Name -ErrorAction SilentlyContinue | Where-Object { $_.SID.Value -eq $testUser.SID.Value })
if (-not $userMembers -or $adminMembers) { throw 'DirnavTestUser must be a standard member of Users and not a member of Administrators.' }

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$ownerSid = $identity.User.Value
$testSid = $testUser.SID.Value
$testProfileBefore = @(Get-CimInstance Win32_UserProfile -Filter "SID='$testSid'" -ErrorAction Stop | Select-Object SID,LocalPath,Loaded,Special)
$programFiles = [IO.Path]::GetFullPath($env:ProgramFiles)
if (-not (Test-Path -LiteralPath $programFiles -PathType Container)) { throw 'Program Files root is unavailable.' }
$runId = [guid]::NewGuid().ToString('N')
$stage = Join-Path $programFiles "DirnavAudit-$runId"
$root = Join-Path $stage 'Root'
$resultsDir = Join-Path $stage 'Results'
$manifestPath = Join-Path $stage 'manifest.json'
$markerPath = Join-Path $stage '.dirnav-audit-marker'
$createdNames = @('read.cmd','edit.cmd','replace.cmd','delete.cmd','rename.cmd','dacl.cmd','owner.cmd')
$nativeModule = Join-Path $PSScriptRoot 'DirnavAudit.Native.psm1'
$adversaryScript = Join-Path $PSScriptRoot 'Invoke-DirnavAdversary.ps1'
$pythonLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
if ($pythonLauncher) { $pythonExecutable=$pythonLauncher.Source; $pythonPrefix=@('-3') }
else {
    $pythonLauncher = Get-Command python.exe -ErrorAction SilentlyContinue
    if (-not $pythonLauncher) { throw 'Python 3 was not found (py.exe or python.exe required).' }
    $pythonExecutable=$pythonLauncher.Source; $pythonPrefix=@()
}

function Assert-StageAcl([string]$Path, [string]$ExpectedOwner) {
    $snap = Get-DirnavAuditAclSnapshot -Path $Path
    if (-not $snap.Protected -or $snap.OwnerSid -ne $ExpectedOwner -or $snap.Aces.Count -ne 4) {
        throw "Unexpected staging DACL at $Path"
    }
    $allowed = @($ownerSid, 'S-1-5-18', 'S-1-5-32-544', $testSid)
    if (@($snap.Aces | Where-Object { $_.Sid -notin $allowed -or $_.Type -ne 'Allow' -or $_.Inherited }).Count) {
        throw "Unexpected staging ACE at $Path"
    }
    $testAce = @($snap.Aces | Where-Object Sid -eq $testSid)
    $unsafe = 0x00000002 -bor 0x00000004 -bor 0x00000010 -bor 0x00000040 -bor 0x00000100 -bor 0x00010000 -bor 0x00040000 -bor 0x00080000 -bor 0x10000000 -bor 0x40000000
    if ($testAce.Count -ne 1 -or ($testAce[0].Rights -band $unsafe)) {
        throw "Staging grants the adversary write/delete/ACL/owner rights at $Path"
    }
}

$oldUserProfile = $env:USERPROFILE
$oldNames = $env:DIRNAV_F15_NAMES
$oldProject = $env:DIRNAV_F15_PROJECT
$createdNonce = $null
$stageCreated = $false
$target = Join-Path $root 'selected & ^ % ! (ç)'
try {
    $stageSddl = "O:$ownerSid`G:SY`D:P(A;OICI;FA;;;$ownerSid)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;GRGX;;;$testSid)"
    $rootSddl = $stageSddl
    $resultsSddl = $stageSddl
    New-DirnavAuditProtectedDirectory -Path $stage -Sddl $stageSddl
    $stageCreated = $true
    Set-Content -LiteralPath $markerPath -Value "$runId|$ownerSid|$testSid" -NoNewline -Encoding ascii
    New-DirnavAuditProtectedDirectory -Path $root -Sddl $rootSddl
    New-DirnavAuditProtectedDirectory -Path $resultsDir -Sddl $resultsSddl
    $resultFile = Join-Path $resultsDir 'adversarial.json'
    $replacePayload = Join-Path $resultsDir 'replacement-payload.cmd'
    $resultFileSddl = "O:$ownerSid`G:SY`D:P(A;;FA;;;$ownerSid)(A;;FA;;;SY)(A;;FA;;;BA)(A;;GW;;;$testSid)"
    $payloadSddl = "O:$ownerSid`G:SY`D:P(A;;FA;;;$ownerSid)(A;;FA;;;SY)(A;;FA;;;BA)(A;;GR;;;$testSid)"
    New-DirnavAuditProtectedFile -Path $resultFile -Sddl $resultFileSddl
    New-DirnavAuditProtectedFile -Path $replacePayload -Sddl $payloadSddl
    [IO.File]::WriteAllText($replacePayload,'@echo off' + "`r`necho replacement`r`n",[Text.UTF8Encoding]::new($false))
    Assert-StageAcl -Path $stage -ExpectedOwner $ownerSid
    Assert-StageAcl -Path $root -ExpectedOwner $ownerSid
    $null = [IO.Directory]::CreateDirectory($target)

    Copy-Item -LiteralPath $nativeModule -Destination (Join-Path $stage 'DirnavAudit.Native.psm1')
    Copy-Item -LiteralPath $adversaryScript -Destination (Join-Path $stage 'Invoke-DirnavAdversary.ps1')

    $bootstrap = @'
import importlib.machinery, importlib.util, json, os
loader=importlib.machinery.SourceFileLoader('dirnav_f15', os.path.abspath(os.environ['DIRNAV_F15_PROJECT'] + '/dirnav'))
spec=importlib.util.spec_from_loader(loader.name, loader)
mod=importlib.util.module_from_spec(spec); loader.exec_module(mod)
names=json.loads(os.environ['DIRNAV_F15_NAMES'])
root=os.path.abspath(os.environ['USERPROFILE'])
target=os.path.join(root, 'selected & ^ % ! (ç)')
nonce=mod.create_secure_cmd_temp_directory()
secure=os.path.join(root, 'dirnav-cmd-'+nonce)
for name in names:
    path=os.path.join(secure, name)
    script=mod.build_cmd_directory_script(target, 65001)
    mod._write_secure_cmd_batch(path, script)
print(json.dumps({'nonce':nonce,'secureDirectory':secure,'target':target}))
'@
    $env:USERPROFILE = $root
    $env:DIRNAV_F15_PROJECT = [IO.Path]::GetFullPath($ProjectRoot)
    $env:DIRNAV_F15_NAMES = ConvertTo-Json -InputObject $createdNames -Compress
    $pythonOutput = & $pythonExecutable @pythonPrefix -c $bootstrap
    if ($LASTEXITCODE -ne 0) { throw "Python secure artifact creation failed with exit code $LASTEXITCODE" }
    $created = ($pythonOutput | Select-Object -Last 1) | ConvertFrom-Json
    $createdNonce = [string]$created.nonce
    $secureDirectory = [string]$created.secureDirectory
    if ($created.target -ne $target) { throw 'Python created artifacts for an unexpected target.' }

    $artifactSnapshot = Get-DirnavAuditAclSnapshot -Path $secureDirectory
    Assert-StageAcl -Path $resultsDir -ExpectedOwner $ownerSid
    foreach ($fileInfo in @(
        @{Path=$resultFile; ExpectedMasks=@('0x40000000','0x00120116')},
        @{Path=$replacePayload; ExpectedMasks=@('0x80000000','0x00120089')}
    )) {
        $fileAcl=Get-DirnavAuditAclSnapshot -Path $fileInfo.Path
        $testAces=@($fileAcl.Aces | Where-Object Sid -eq $testSid)
        $testRights=if($testAces.Count -eq 1){'0x{0:X8}' -f $testAces[0].Rights}else{$null}
        if (-not $fileAcl.Protected -or $fileAcl.OwnerSid -ne $ownerSid -or $fileAcl.Aces.Count -ne 4 -or $testAces.Count -ne 1 -or $testRights -notin $fileInfo.ExpectedMasks -or $testAces[0].Inherited) {
            throw "Unexpected isolated results-file DACL at $($fileInfo.Path)"
        }
    }
    $artifactItems = @()
    foreach ($artifactName in $createdNames) {
        $path = Join-Path $secureDirectory $artifactName
        $snap = Get-DirnavAuditAclSnapshot -Path $path
        if (-not $snap.Protected -or $snap.OwnerSid -ne $ownerSid -or $snap.Aces.Count -ne 3) {
            throw "Production helper created unexpected DACL for $artifactName"
        }
        $allowed = @($ownerSid, 'S-1-5-18', 'S-1-5-32-544')
        if (@($snap.Aces | Where-Object { $_.Sid -notin $allowed -or $_.Type -ne 'Allow' -or $_.Inherited }).Count) {
            throw "Production helper created unexpected ACE for $artifactName"
        }
        $artifactItems += [pscustomobject]@{
            Name = $artifactName
            Path = $path
            Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            Sddl = $snap.Sddl
        }
    }
    if (-not $artifactSnapshot.Protected -or $artifactSnapshot.OwnerSid -ne $ownerSid) {
        throw 'Production helper created an unexpected protected directory.'
    }
    $rootSnapshot = Get-DirnavAuditAclSnapshot -Path $root
    $manifest = [pscustomobject]@{
        Schema = 'dirnav-adversarial-v1'
        RunId = $runId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
        StageRoot = $stage
        StageOwnerSid = $ownerSid
        TestUser = $testUser.Name
        TestUserSid = $testSid
        TestUserProfileBefore = $testProfileBefore
        Root = $root
        RootSddl = $rootSnapshot.Sddl
        ResultsDirectory = $resultsDir
        SecureDirectory = $secureDirectory
        SecureDirectorySddl = $artifactSnapshot.Sddl
        Target = $target
        ResultFile = (Join-Path $resultsDir 'adversarial.json')
        ReplaceSource = $replacePayload
        OwnerRegressionPath = (Join-Path ([IO.Path]::GetFullPath($ProjectRoot)) "docs\audit\results\f15-owner-regression-$runId.json")
        Items = $artifactItems
    }
    $encoding = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $encoding)
    if (-not (Test-Path -LiteralPath $manifestPath) -or (Get-DirnavAuditAclSnapshot $secureDirectory).Aces.Count -ne 3) {
        throw 'Final preparation verification failed.'
    }
    "RUN_ID=$runId"
    "MANIFEST=$manifestPath"
    "ADVERSARY_SCRIPT=$(Join-Path $stage 'Invoke-DirnavAdversary.ps1')"
    "RESULT_FILE=$(Join-Path $resultsDir 'adversarial.json')"
    "BATCH_DIRECTORY=$secureDirectory"
} catch {
    $failure = $_
    if ($stageCreated -and (Test-Path -LiteralPath $stage)) {
        try {
            $expectedStage = Join-Path ([IO.Path]::GetFullPath($env:ProgramFiles)) "DirnavAudit-$runId"
            if (-not ([IO.Path]::GetFullPath($stage)).Equals([IO.Path]::GetFullPath($expectedStage),[StringComparison]::OrdinalIgnoreCase)) { throw 'Rollback stage identity mismatch.' }
            if ((Get-Item -LiteralPath $stage -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Rollback stage became a reparse point.' }
            if (Test-Path -LiteralPath $markerPath) {
                if ((Get-Item -LiteralPath $markerPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Rollback marker became a reparse point.' }
                $expectedMarker = "$runId|$ownerSid|$testSid"
                if ((Get-Content -LiteralPath $markerPath -Raw -Encoding Ascii) -ne $expectedMarker) { throw 'Rollback marker mismatch; preserving staging directory.' }
            }
            foreach ($rollbackDir in @($root,$resultsDir)) {
                if (Test-Path -LiteralPath $rollbackDir) {
                    if ((Get-Item -LiteralPath $rollbackDir -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Rollback directory became a reparse point: $rollbackDir" }
                    if (-not ([IO.Path]::GetFullPath((Split-Path -Parent $rollbackDir))).Equals([IO.Path]::GetFullPath($stage),[StringComparison]::OrdinalIgnoreCase)) { throw "Rollback directory escaped staging: $rollbackDir" }
                }
            }
            if (Test-Path -LiteralPath $root) {
                foreach ($entry in @(Get-ChildItem -LiteralPath $root -Force)) {
                    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Rollback found a reparse point at $($entry.FullName)" }
                    if ($entry.PSIsContainer -and $entry.Name -match '^dirnav-cmd-[0-9a-f]{32}$') {
                        foreach ($batch in @(Get-ChildItem -LiteralPath $entry.FullName -Force)) {
                            if ($batch.PSIsContainer -or $batch.Attributes -band [IO.FileAttributes]::ReparsePoint -or $batch.Name -notin $createdNames) { throw "Rollback found an unexpected batch item at $($batch.FullName)" }
                            [IO.File]::Delete($batch.FullName)
                        }
                        [IO.Directory]::Delete($entry.FullName,$false)
                    } elseif ($entry.PSIsContainer -and $entry.FullName -eq $target) {
                        [IO.Directory]::Delete($entry.FullName,$false)
                    } else { throw "Rollback found an unexpected root item at $($entry.FullName)" }
                }
                [IO.Directory]::Delete($root,$false)
            }
            if (Test-Path -LiteralPath $resultsDir) {
                foreach ($resultName in @('adversarial.json','replacement-payload.cmd')) {
                    $path=Join-Path $resultsDir $resultName
                    if (Test-Path -LiteralPath $path) {
                        $item=Get-Item -LiteralPath $path -Force
                        if ($item.PSIsContainer -or $item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Rollback found unexpected results item at $path" }
                        [IO.File]::Delete($path)
                    }
                }
                if (@(Get-ChildItem -LiteralPath $resultsDir -Force).Count) { throw 'Rollback found unexpected files in Results.' }
                [IO.Directory]::Delete($resultsDir,$false)
            }
            $knownStageFiles = @('DirnavAudit.Native.psm1','Invoke-DirnavAdversary.ps1','manifest.json','.dirnav-audit-marker')
            foreach ($stageName in $knownStageFiles) {
                $path=Join-Path $stage $stageName
                if (Test-Path -LiteralPath $path) {
                    $item=Get-Item -LiteralPath $path -Force
                    if ($item.PSIsContainer -or $item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Rollback found an unexpected stage item at $path" }
                    [IO.File]::Delete($path)
                }
            }
            if (@(Get-ChildItem -LiteralPath $stage -Force).Count) { throw 'Rollback left unidentified staging entries.' }
            [IO.Directory]::Delete($stage,$false)
        } catch {
            Write-Warning "Safe rollback stopped; inspect only this generated directory: $stage. Cause: $($_.Exception.Message)"
        }
    }
    Write-Warning $failure.Exception.Message
    throw
} finally {
    if ($null -eq $oldUserProfile) { Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue } else { $env:USERPROFILE = $oldUserProfile }
    if ($null -eq $oldNames) { Remove-Item Env:DIRNAV_F15_NAMES -ErrorAction SilentlyContinue } else { $env:DIRNAV_F15_NAMES = $oldNames }
    if ($null -eq $oldProject) { Remove-Item Env:DIRNAV_F15_PROJECT -ErrorAction SilentlyContinue } else { $env:DIRNAV_F15_PROJECT = $oldProject }
}
