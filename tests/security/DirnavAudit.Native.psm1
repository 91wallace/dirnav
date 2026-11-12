Set-StrictMode -Version Latest

$nativeSource = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class DirnavAuditNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct SecurityAttributes
    {
        public int nLength;
        public IntPtr lpSecurityDescriptor;
        [MarshalAs(UnmanagedType.Bool)] public bool bInheritHandle;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct GenericMapping
    {
        public uint GenericRead;
        public uint GenericWrite;
        public uint GenericExecute;
        public uint GenericAll;
    }

    [DllImport("advapi32.dll", EntryPoint = "ConvertStringSecurityDescriptorToSecurityDescriptorW", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
    private static extern bool ConvertStringSecurityDescriptorToSecurityDescriptorW(
        string sddl, uint revision, out IntPtr descriptor, out uint size);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetSecurityDescriptorDacl(IntPtr descriptor,
        [MarshalAs(UnmanagedType.Bool)] out bool present, out IntPtr dacl,
        [MarshalAs(UnmanagedType.Bool)] out bool defaulted);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetSecurityDescriptorOwner(IntPtr descriptor,
        out IntPtr owner, [MarshalAs(UnmanagedType.Bool)] out bool defaulted);

    [DllImport("advapi32.dll", EntryPoint = "SetNamedSecurityInfoW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint SetNamedSecurityInfoW(string objectName, int objectType,
        uint securityInfo, IntPtr owner, IntPtr group, IntPtr dacl, IntPtr sacl);

    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
    private static extern bool CreateDirectoryW(string path, ref SecurityAttributes attributes);

    [DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
    private static extern IntPtr CreateFileW(string path, uint access, uint share,
        ref SecurityAttributes attributes, uint creationDisposition, uint flags, IntPtr template);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AccessCheck(
        IntPtr descriptor, IntPtr clientToken, uint desiredAccess,
        ref GenericMapping mapping, IntPtr privilegeSet, ref uint privilegeSetLength,
        out uint grantedAccess, [MarshalAs(UnmanagedType.Bool)] out bool accessStatus);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool DuplicateToken(IntPtr existingToken, int level, out IntPtr duplicateToken);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr memory);

    public static void CreateFileProtected(string path, string sddl)
    {
        IntPtr descriptor = IntPtr.Zero;
        uint size;
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out descriptor, out size))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SDDL conversion failed");
        try
        {
            SecurityAttributes attributes = new SecurityAttributes();
            attributes.nLength = Marshal.SizeOf(typeof(SecurityAttributes));
            attributes.lpSecurityDescriptor = descriptor;
            attributes.bInheritHandle = false;
            IntPtr handle = CreateFileW(path, 0x40000000, 0, ref attributes, 1, 0x80, IntPtr.Zero);
            if (handle == new IntPtr(-1))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateFileW(CREATE_NEW) failed");
            try
            {
                if (!CloseHandle(handle))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CloseHandle failed");
            }
            catch
            {
                CloseHandle(handle);
                throw;
            }
        }
        finally
        {
            LocalFree(descriptor);
        }
    }

    public static void TrySetDaclFromSddl(string path, string sddl)
    {
        IntPtr descriptor = IntPtr.Zero;
        uint size;
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out descriptor, out size))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SDDL conversion failed");
        try
        {
            bool present, defaulted;
            IntPtr dacl;
            if (!GetSecurityDescriptorDacl(descriptor, out present, out dacl, out defaulted) || !present || dacl == IntPtr.Zero)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetSecurityDescriptorDacl failed");
            uint status = SetNamedSecurityInfoW(path, 1, 0x00000004 | 0x80000000, IntPtr.Zero, IntPtr.Zero, dacl, IntPtr.Zero);
            if (status != 0) throw new Win32Exception((int)status, "SetNamedSecurityInfoW(DACL) failed");
        }
        finally { LocalFree(descriptor); }
    }

    public static void TrySetOwnerFromSddl(string path, string sddl)
    {
        IntPtr descriptor = IntPtr.Zero;
        uint size;
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out descriptor, out size))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SDDL conversion failed");
        try
        {
            bool defaulted;
            IntPtr owner;
            if (!GetSecurityDescriptorOwner(descriptor, out owner, out defaulted) || owner == IntPtr.Zero)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetSecurityDescriptorOwner failed");
            uint status = SetNamedSecurityInfoW(path, 1, 0x00000001, owner, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
            if (status != 0) throw new Win32Exception((int)status, "SetNamedSecurityInfoW(owner) failed");
        }
        finally { LocalFree(descriptor); }
    }

    public static void RestoreOwnerAndDaclFromSddl(string path, string sddl)
    {
        IntPtr descriptor = IntPtr.Zero;
        uint size;
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out descriptor, out size))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SDDL conversion failed");
        try
        {
            bool present, daclDefaulted, ownerDefaulted;
            IntPtr dacl, owner;
            if (!GetSecurityDescriptorDacl(descriptor, out present, out dacl, out daclDefaulted) || !present || dacl == IntPtr.Zero)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetSecurityDescriptorDacl failed");
            if (!GetSecurityDescriptorOwner(descriptor, out owner, out ownerDefaulted) || owner == IntPtr.Zero)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetSecurityDescriptorOwner failed");
            uint status = SetNamedSecurityInfoW(path, 1, 0x00000001 | 0x00000004 | 0x80000000,
                owner, IntPtr.Zero, dacl, IntPtr.Zero);
            if (status != 0) throw new Win32Exception((int)status, "SetNamedSecurityInfoW(restore owner/DACL) failed");
        }
        finally { LocalFree(descriptor); }
    }

    [DllImport("advapi32.dll")]
    private static extern void MapGenericMask(ref uint accessMask, ref GenericMapping mapping);

    public static void ValidateSddl(string sddl)
    {
        IntPtr descriptor = IntPtr.Zero;
        uint size;
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out descriptor, out size))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SDDL validation failed");
        if (descriptor != IntPtr.Zero) LocalFree(descriptor);
    }

    public static void CreateDirectoryProtected(string path, string sddl)
    {
        IntPtr descriptor = IntPtr.Zero;
        uint size;
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out descriptor, out size))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SDDL conversion failed");
        try
        {
            SecurityAttributes attributes = new SecurityAttributes();
            attributes.nLength = Marshal.SizeOf(typeof(SecurityAttributes));
            attributes.lpSecurityDescriptor = descriptor;
            attributes.bInheritHandle = false;
            if (!CreateDirectoryW(path, ref attributes))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateDirectoryW failed");
        }
        finally
        {
            LocalFree(descriptor);
        }
    }

    public static object CheckCurrentTokenAccess(string sddl, uint desiredAccess)
    {
        IntPtr descriptor = IntPtr.Zero;
        IntPtr token = IntPtr.Zero;
        IntPtr impersonationToken = IntPtr.Zero;
        IntPtr privilegeSet = IntPtr.Zero;
        uint size;
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out descriptor, out size))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SDDL conversion failed");
        try
        {
            if (!OpenProcessToken(GetCurrentProcess(), 0x000A, out token))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "OpenProcessToken failed");
            if (!DuplicateToken(token, 2, out impersonationToken))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "DuplicateToken failed");

            GenericMapping mapping = new GenericMapping();
            mapping.GenericRead = 0x00120089;
            mapping.GenericWrite = 0x00120116;
            mapping.GenericExecute = 0x001200A0;
            mapping.GenericAll = 0x001F01FF;
            MapGenericMask(ref desiredAccess, ref mapping);

            uint privilegeSetLength = 4096;
            privilegeSet = Marshal.AllocHGlobal((int)privilegeSetLength);
            uint granted;
            bool allowed;
            if (!AccessCheck(descriptor, impersonationToken, desiredAccess, ref mapping,
                    privilegeSet, ref privilegeSetLength, out granted, out allowed))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "AccessCheck failed");
            return new { Allowed = allowed, GrantedAccess = granted, RequestedAccess = desiredAccess };
        }
        finally
        {
            if (privilegeSet != IntPtr.Zero) Marshal.FreeHGlobal(privilegeSet);
            if (impersonationToken != IntPtr.Zero) CloseHandle(impersonationToken);
            if (token != IntPtr.Zero) CloseHandle(token);
            if (descriptor != IntPtr.Zero) LocalFree(descriptor);
        }
    }
}
'@

if (-not ('DirnavAuditNative' -as [type])) {
    Add-Type -TypeDefinition $nativeSource -Language CSharp -ErrorAction Stop
}

function New-DirnavAuditProtectedDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Sddl
    )
    [DirnavAuditNative]::CreateDirectoryProtected($Path, $Sddl)
}

function New-DirnavAuditProtectedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Sddl
    )
    [DirnavAuditNative]::CreateFileProtected($Path, $Sddl)
}

function Get-DirnavAuditAclSnapshot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $ownerSid = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    $aces = @(
        foreach ($ace in $acl.Access) {
            $sid = $ace.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            [pscustomobject]@{
                Sid = $sid
                Type = $ace.AccessControlType.ToString()
                Rights = [uint32]$ace.FileSystemRights.value__
                Inherited = [bool]$ace.IsInherited
                Inheritance = $ace.InheritanceFlags.ToString()
                Propagation = $ace.PropagationFlags.ToString()
            }
        }
    )
    [pscustomobject]@{
        Path = $Path
        OwnerSid = $ownerSid
        Protected = [bool]$acl.AreAccessRulesProtected
        Sddl = $acl.GetSecurityDescriptorSddlForm(
            [Security.AccessControl.AccessControlSections]::Owner -bor
            [Security.AccessControl.AccessControlSections]::Group -bor
            [Security.AccessControl.AccessControlSections]::Access)
        Aces = $aces
    }
}

function Assert-DirnavAuditManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$ManifestPath,
        [string]$ProgramFilesRoot = $env:ProgramFiles,
        [string]$ExpectedProjectRoot
    )
    if ($Manifest.Schema -ne 'dirnav-adversarial-v1' -or [string]$Manifest.RunId -notmatch '^[0-9a-f]{32}$') { throw 'Invalid audit manifest schema or run identifier.' }
    foreach ($field in @('StageOwnerSid','TestUserSid')) {
        if ([string]$Manifest.$field -notmatch '^S-1-(?:[0-9]+-)*[0-9]+$') { throw "Invalid SID in manifest field $field." }
    }
    if ([string]$Manifest.TestUser -ne 'DirnavTestUser') { throw 'Unexpected adversarial account name in manifest.' }
    if ([string]$Manifest.StageOwnerSid -eq [string]$Manifest.TestUserSid) { throw 'Owner and adversarial identities must be distinct.' }
    $pf = [IO.Path]::GetFullPath($ProgramFilesRoot).TrimEnd('\')
    $expectedStage = Join-Path $pf "DirnavAudit-$($Manifest.RunId)"
    $stage = [IO.Path]::GetFullPath([string]$Manifest.StageRoot)
    $manifestFull = [IO.Path]::GetFullPath($ManifestPath)
    if (-not $stage.Equals($expectedStage,[StringComparison]::OrdinalIgnoreCase) -or
        -not $manifestFull.Equals((Join-Path $stage 'manifest.json'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest path is outside its run-specific staging directory.' }

    $root = Join-Path $stage 'Root'
    $results = Join-Path $stage 'Results'
    $secureName = [IO.Path]::GetFileName([string]$Manifest.SecureDirectory)
    if ($secureName -notmatch '^dirnav-cmd-[0-9a-f]{32}$') { throw 'Invalid secure-directory identifier.' }
    $secure = Join-Path $root $secureName
    $target = Join-Path $root 'selected & ^ % ! (ç)'
    $expected = @{
        Root=$root; ResultsDirectory=$results; SecureDirectory=$secure; Target=$target
        ResultFile=(Join-Path $results 'adversarial.json')
        ReplaceSource=(Join-Path $results 'replacement-payload.cmd')
        OwnerRegressionPath=(Join-Path ([IO.Path]::GetFullPath([string]$Manifest.ProjectRoot)) "docs\audit\results\f15-owner-regression-$($Manifest.RunId).json")
    }
    foreach ($key in $expected.Keys) {
        $actual = [IO.Path]::GetFullPath([string]$Manifest.$key)
        if (-not $actual.Equals([IO.Path]::GetFullPath([string]$expected[$key]),[StringComparison]::OrdinalIgnoreCase)) { throw "Manifest path mismatch: $key." }
    }
    if (-not (Test-Path -LiteralPath $Manifest.ProjectRoot -PathType Container)) { throw 'ProjectRoot is missing.' }
    if ($ExpectedProjectRoot) {
        $expectedProject = [IO.Path]::GetFullPath($ExpectedProjectRoot).TrimEnd('\')
        $actualProject = [IO.Path]::GetFullPath([string]$Manifest.ProjectRoot).TrimEnd('\')
        if (-not $actualProject.Equals($expectedProject,[StringComparison]::OrdinalIgnoreCase)) { throw 'ProjectRoot does not match the executing checkout.' }
    }
    if (@($Manifest.Items).Count -ne 7) { throw 'Manifest must contain exactly seven artifact records.' }
    $names = @('read.cmd','edit.cmd','replace.cmd','delete.cmd','rename.cmd','dacl.cmd','owner.cmd')
    if (@($Manifest.Items | ForEach-Object { [string]$_.Name } | Sort-Object -Unique).Count -ne 7) { throw 'Manifest artifact names are duplicated or invalid.' }
    foreach ($item in $Manifest.Items) {
        if ($item.Name -notin $names -or -not ([IO.Path]::GetFullPath([string]$item.Path)).Equals((Join-Path $secure ([string]$item.Name)),[StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest contains an unexpected artifact path or name.' }
        if ([string]$item.Sha256 -notmatch '^[0-9A-Fa-f]{64}$' -or [string]::IsNullOrWhiteSpace([string]$item.Sddl)) { throw "Invalid artifact integrity record: $($item.Name)." }
        [DirnavAuditNative]::ValidateSddl([string]$item.Sddl)
    }
    if (@($Manifest.Items | ForEach-Object { [string]$_.Name } | Where-Object { $_ -notin $names }).Count) { throw 'Manifest contains unknown artifact names.' }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.SecureDirectorySddl) -or [string]::IsNullOrWhiteSpace([string]$Manifest.RootSddl)) { throw 'Manifest security descriptors are missing.' }
    [DirnavAuditNative]::ValidateSddl([string]$Manifest.SecureDirectorySddl)
    [DirnavAuditNative]::ValidateSddl([string]$Manifest.RootSddl)
    [pscustomobject]@{ Stage=$stage; Root=$root; Results=$results; Secure=$secure; Target=$target; Items=@($Manifest.Items) }
}

function Read-DirnavAuditManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ManifestPath,[string]$ProgramFilesRoot=$env:ProgramFiles,[string]$ExpectedProjectRoot)
    $full = [IO.Path]::GetFullPath($ManifestPath)
    $stage = Split-Path -Parent $full
    $pf = [IO.Path]::GetFullPath($ProgramFilesRoot).TrimEnd('\')
    if (-not (Split-Path -Leaf $full).Equals('manifest.json',[StringComparison]::OrdinalIgnoreCase) -or
        -not (Split-Path -Parent $stage).TrimEnd('\').Equals($pf,[StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $stage) -notmatch '^DirnavAudit-[0-9a-f]{32}$') { throw 'Manifest path is not a recognized audit staging path.' }
    Assert-DirnavNoReparseChain -Path $full | Out-Null
    foreach ($path in @($stage,$full)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf -ErrorAction SilentlyContinue) -and $path -eq $full) { throw 'Manifest file is missing.' }
        if (-not (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)) { throw "Manifest path is missing: $path" }
        if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Manifest path contains a reparse point: $path" }
    }
    $manifest = Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $validated = Assert-DirnavAuditManifest -Manifest $manifest -ManifestPath $full -ProgramFilesRoot $ProgramFilesRoot -ExpectedProjectRoot $ExpectedProjectRoot
    [pscustomobject]@{ Manifest=$manifest; Paths=$validated; Path=$full }
}

function Assert-DirnavNoReparseChain {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $current=[IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current -ErrorAction SilentlyContinue) {
            $entry=Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing reparse point in path chain: $current" }
        }
        $parent=Split-Path -Parent $current
        if (-not $parent -or $parent.Equals($current,[StringComparison]::OrdinalIgnoreCase)) { break }
        $current=$parent
    }
    return $true
}

function Test-DirnavAuditSecurityDescriptorEquivalent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ActualSddl,[Parameter(Mandatory)][string]$ExpectedSddl)
    # SetNamedSecurityInfo may preserve the DACL auto-inherited control bit (AI)
    # even when the DACL is protected. Keep ACEs and all other descriptor fields exact.
    $actualNormalized=[regex]::Replace($ActualSddl,'D:PAI(?=\()','D:P')
    $expectedNormalized=[regex]::Replace($ExpectedSddl,'D:PAI(?=\()','D:P')
    return $actualNormalized.Equals($expectedNormalized,[StringComparison]::OrdinalIgnoreCase)
}

function Write-DirnavAuditEvidenceExclusive {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Json)
    $stream = [IO.FileStream]::new($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Json)
        $stream.Write($bytes,0,$bytes.Length)
        $stream.Flush($true)
    } finally { $stream.Dispose() }
    $persisted = [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
    if (-not $persisted.Equals($Json,[StringComparison]::Ordinal)) { throw 'Persisted evidence verification failed.' }
    $null = $persisted | ConvertFrom-Json -ErrorAction Stop
    return $true
}

function Invoke-DirnavAuditCleanupAfterPersistence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EvidencePath,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][scriptblock]$CleanupAction
    )
    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) { throw 'Final evidence is not persisted; cleanup is forbidden.' }
    if ((Get-Item -LiteralPath $EvidencePath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Final evidence path is a reparse point; cleanup is forbidden.' }
    $evidence = Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    if ($evidence.Schema -ne 'dirnav-f15-final-v1' -or $evidence.RunId -ne $RunId) { throw 'Persisted final evidence does not match this run; cleanup is forbidden.' }
    & $CleanupAction
    return $true
}

Export-ModuleMember -Function New-DirnavAuditProtectedDirectory, New-DirnavAuditProtectedFile, Get-DirnavAuditAclSnapshot, Assert-DirnavAuditManifest, Read-DirnavAuditManifest, Assert-DirnavNoReparseChain, Test-DirnavAuditSecurityDescriptorEquivalent, Write-DirnavAuditEvidenceExclusive, Invoke-DirnavAuditCleanupAfterPersistence
