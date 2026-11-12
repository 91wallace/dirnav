[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DirnavAudit.Native.psm1') -Force
$manifestPath = [IO.Path]::GetFullPath($ManifestPath)
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.Schema -ne 'dirnav-adversarial-v1') { throw 'Unsupported manifest schema.' }

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if ($identity.User.Value -ne $manifest.TestUserSid) { throw 'This script must run as the designated test identity.' }
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdministrator) { throw 'Refusing to run adversarial probes with an administrator token.' }

$probes = [Collections.Generic.List[object]]::new()
$accessChecks = [Collections.Generic.List[object]]::new()
$ancestorChecks = [Collections.Generic.List[object]]::new()

function Get-Win32ErrorCode([Exception]$Exception) {
    $hex = '0x{0:X8}' -f [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$Exception.HResult),0)
    if ($hex.StartsWith('0x8007',[StringComparison]::OrdinalIgnoreCase)) { return [Convert]::ToInt32($hex.Substring(6),16) }
    if ($Exception -is [ComponentModel.Win32Exception]) { return $Exception.NativeErrorCode }
    return $null
}
function Get-HResultHex([Exception]$Exception) {
    return '0x{0:X8}' -f [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$Exception.HResult),0)
}

function Add-Attempt([string]$Name, [string]$Path, [scriptblock]$Operation) {
    $started = [DateTime]::UtcNow.ToString('o')
    try {
        & $Operation
        $probes.Add([pscustomobject]@{ Name=$Name; Path=$Path; Result='UNEXPECTED_SUCCESS'; HResult='0x00000000'; Win32Code=0; ErrorType=$null; Message=$null; StartedUtc=$started })
    } catch {
        $exception = $_.Exception
        $probes.Add([pscustomobject]@{ Name=$Name; Path=$Path; Result='DENIED_OR_ERROR'; HResult=(Get-HResultHex $exception); Win32Code=(Get-Win32ErrorCode $exception); ErrorType=$exception.GetType().FullName; Message=$exception.Message; StartedUtc=$started })
    }
}

function Add-AccessCheck([string]$Scope, [string]$Sddl, [string]$Right, [uint32]$Mask) {
    try {
        $check = [DirnavAuditNative]::CheckCurrentTokenAccess($Sddl, $Mask)
        $accessChecks.Add([pscustomobject]@{ Scope=$Scope; Right=$Right; Allowed=[bool]$check.Allowed; RequestedMask=('0x{0:X8}' -f [uint32]$check.RequestedAccess); GrantedMask=('0x{0:X8}' -f [uint32]$check.GrantedAccess); ErrorCode=$null })
    } catch {
        $accessChecks.Add([pscustomobject]@{ Scope=$Scope; Right=$Right; Allowed=$null; RequestedMask=('0x{0:X8}' -f $Mask); GrantedMask=$null; ErrorCode=(Get-Win32ErrorCode $_.Exception); Error=$_.Exception.Message })
    }
}

foreach ($path in @($manifest.StageRoot, $manifest.Root, $manifest.SecureDirectory, $manifest.Items[0].Path)) {
    try {
        [void](Get-Item -LiteralPath $path -ErrorAction Stop)
        $ancestorChecks.Add([pscustomobject]@{ Path=$path; Result='ACCESSIBLE'; HResult='0x00000000'; Win32Code=0 })
    } catch {
        $ancestorChecks.Add([pscustomobject]@{ Path=$path; Result='BLOCKED'; HResult=(Get-HResultHex $_.Exception); Win32Code=(Get-Win32ErrorCode $_.Exception) })
    }
}

$directoryRights = @(
    @{Name='ListDirectory';Mask=[uint32]0x00000001},
    @{Name='CreateFile';Mask=[uint32]0x00000002},
    @{Name='CreateDirectory';Mask=[uint32]0x00000004},
    @{Name='DeleteChild';Mask=[uint32]0x00000040},
    @{Name='DeleteDirectory';Mask=[uint32]0x00010000},
    @{Name='WriteDacl';Mask=[uint32]0x00040000},
    @{Name='WriteOwner';Mask=[uint32]0x00080000}
)
$fileRights = @(
    @{Name='ReadData';Mask=[uint32]0x00000001},
    @{Name='WriteData';Mask=[uint32]0x00000002},
    @{Name='AppendData';Mask=[uint32]0x00000004},
    @{Name='Delete';Mask=[uint32]0x00010000},
    @{Name='WriteDacl';Mask=[uint32]0x00040000},
    @{Name='WriteOwner';Mask=[uint32]0x00080000}
)
foreach ($right in $directoryRights) { Add-AccessCheck 'SecureDirectoryDacl' $manifest.SecureDirectorySddl $right.Name $right.Mask }
foreach ($item in $manifest.Items) {
    foreach ($right in $fileRights) { Add-AccessCheck "BatchDacl:$($item.Name)" $item.Sddl $right.Name $right.Mask }
}

$readItem = $manifest.Items | Where-Object Name -eq 'read.cmd' | Select-Object -First 1
$editItem = $manifest.Items | Where-Object Name -eq 'edit.cmd' | Select-Object -First 1
$replaceItem = $manifest.Items | Where-Object Name -eq 'replace.cmd' | Select-Object -First 1
$deleteItem = $manifest.Items | Where-Object Name -eq 'delete.cmd' | Select-Object -First 1
$renameItem = $manifest.Items | Where-Object Name -eq 'rename.cmd' | Select-Object -First 1
$daclItem = $manifest.Items | Where-Object Name -eq 'dacl.cmd' | Select-Object -First 1
$ownerItem = $manifest.Items | Where-Object Name -eq 'owner.cmd' | Select-Object -First 1
$payload = [IO.Path]::GetFullPath([string]$manifest.ReplaceSource)
if (-not $payload.StartsWith(([IO.Path]::GetFullPath($manifest.ResultsDirectory).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Replacement source is outside the isolated results directory.'
}

Add-Attempt 'ReadBatch' $readItem.Path { [void][IO.File]::ReadAllBytes($readItem.Path) }
Add-Attempt 'EditBatch' $editItem.Path { $stream=[IO.File]::Open($editItem.Path,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::None); try{$stream.WriteByte(0x58);$stream.Flush()}finally{$stream.Dispose()} }
Add-Attempt 'ReplaceBatch' $replaceItem.Path { [IO.File]::Copy($payload,$replaceItem.Path,$true) }
Add-Attempt 'DeleteBatch' $deleteItem.Path { [IO.File]::Delete($deleteItem.Path) }
Add-Attempt 'RenameBatch' $renameItem.Path { [IO.File]::Move($renameItem.Path,($renameItem.Path+'.renamed')) }
Add-Attempt 'CreateFileInProtectedDirectory' (Join-Path $manifest.SecureDirectory 'attacker-created.cmd') { [IO.File]::WriteAllText((Join-Path $manifest.SecureDirectory 'attacker-created.cmd'),'@echo off') }
Add-Attempt 'ChangeBatchDacl' $daclItem.Path { [DirnavAuditNative]::TrySetDaclFromSddl($daclItem.Path,"D:P(A;;FA;;;$($identity.User.Value))") }
Add-Attempt 'ChangeBatchOwner' $ownerItem.Path {
    [DirnavAuditNative]::TrySetOwnerFromSddl($ownerItem.Path,"O:$($identity.User.Value)")
}
$directoryGrantSddl="D:P(A;;FA;;;$($manifest.StageOwnerSid))(A;;FA;;;SY)(A;;FA;;;BA)(A;;FA;;;$($identity.User.Value))"
Add-Attempt 'ChangeSecureDirectoryDacl' $manifest.SecureDirectory {
    [DirnavAuditNative]::TrySetDaclFromSddl($manifest.SecureDirectory,$directoryGrantSddl)
}
Add-Attempt 'ChangeSecureDirectoryOwner' $manifest.SecureDirectory {
    [DirnavAuditNative]::TrySetOwnerFromSddl($manifest.SecureDirectory,"O:$($identity.User.Value)")
}

$groups = @($identity.Groups | ForEach-Object { $_.Value })
$report = [pscustomobject]@{
    Schema = 'dirnav-adversarial-results-v1'
    RunId = $manifest.RunId
    ObservedUtc = [DateTime]::UtcNow.ToString('o')
    Identity = [pscustomobject]@{ Name=$identity.Name; Sid=$identity.User.Value; ProcessId=$PID; IsAdministrator=$isAdministrator; GroupSids=$groups }
    AncestorAccess = @($ancestorChecks)
    EffectiveAccessChecks = @($accessChecks)
    Attempts = @($probes)
    Notes = 'Direct operations are performed by this process token. AccessCheck evaluates the recorded object descriptors with this process token; ancestor access probes are reported separately.'
}
$json = $report | ConvertTo-Json -Depth 10
$resultPath = [IO.Path]::GetFullPath($manifest.ResultFile)
try {
    [IO.File]::WriteAllText($resultPath,$json,[Text.UTF8Encoding]::new($false))
} catch {
    Write-Output $json
    throw "Could not persist structured results to the designated Results file: $($_.Exception.Message)"
}
Write-Output $json
