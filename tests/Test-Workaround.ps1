$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\SpotifyDisplayWorkaround.psm1') -Force
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('spotify-workaround-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$script:assertions = 0
function Assert($Condition, [string]$Message) {
    if (!$Condition) { throw "FAIL: $Message" }
    $script:assertions++
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert $threw $Message
}
try {
    $app = Join-Path $testRoot 'app'
    $data = Join-Path $testRoot 'data'
    $module = Join-Path $data 'WidevineCdm'
    $null = New-Item -ItemType Directory -Path $app, $module
    [IO.File]::WriteAllText((Join-Path $app 'Spotify.exe'), 'Test fixture; not executable.')
    [IO.File]::WriteAllText((Join-Path $module 'fixture.txt'), 'Original test content')
    $expectedHash = (Get-FileHash -LiteralPath (Join-Path $module 'fixture.txt')).Hash
    $options = @{SpotifyDirectory = $app; DataDirectory = $data; NoLaunch = $true}
    Enable-DisplayWorkaround @options
    Assert (Test-Path -LiteralPath $module -PathType Leaf) 'Apply creates a file at the Widevine path.'
    Assert ((Get-Item -LiteralPath $module).IsReadOnly) 'The placeholder is read-only.'
    $statePath = Join-Path $data 'spotify-display-workaround.json'
    $saved = Get-Content -LiteralPath $statePath -Raw
    $state = $saved | ConvertFrom-Json
    $backup = Join-Path $data $state.BackupName
    Assert ((Get-FileHash -LiteralPath (Join-Path $backup 'fixture.txt')).Hash -eq $expectedHash) 'Backup preserves original contents.'
    Enable-DisplayWorkaround @options
    Assert (@(Get-ChildItem -LiteralPath $data -Directory -Filter 'WidevineCdm.backup-*').Count -eq 1) 'Repeated apply does not create another backup.'
    (Get-Item -LiteralPath $module).IsReadOnly = $false
    [IO.File]::WriteAllText($module, 'Unexpected content')
    Assert-Throws { Disable-DisplayWorkaround @options } 'Restore refuses modified placeholder content.'
    Assert ((Get-Content -LiteralPath $module -Raw) -eq 'Unexpected content') 'Unexpected content is preserved.'
    [IO.File]::WriteAllText($module, '')
    (Get-Item -LiteralPath $module).IsReadOnly = $true
    $state.BackupName = '..\outside'
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath
    Assert-Throws { Disable-DisplayWorkaround @options } 'Restore rejects a backup path outside the data directory.'
    [IO.File]::WriteAllText($statePath, $saved)
    Rename-Item -LiteralPath $backup -NewName 'temporarily-missing'
    Assert-Throws { Disable-DisplayWorkaround @options } 'Restore refuses a missing backup.'
    Assert (Test-Path -LiteralPath $module -PathType Leaf) 'A missing backup does not remove the placeholder.'
    Rename-Item -LiteralPath (Join-Path $data 'temporarily-missing') -NewName ($state.BackupName = ($saved | ConvertFrom-Json).BackupName)
    Disable-DisplayWorkaround @options
    Assert (Test-Path -LiteralPath $module -PathType Container) 'Restore puts back the original folder.'
    Assert ((Get-FileHash -LiteralPath (Join-Path $module 'fixture.txt')).Hash -eq $expectedHash) 'Restore preserves original contents.'
    Assert (!(Test-Path -LiteralPath $statePath)) 'Restore removes managed state.'
    Assert-Throws { Disable-DisplayWorkaround @options } 'Repeated restore fails safely.'
    Move-Item -LiteralPath $module -Destination (Join-Path $data 'external-backup')
    [IO.File]::WriteAllText($module, '')
    Assert-Throws { Enable-DisplayWorkaround @options } 'Apply refuses an unmanaged placeholder.'
    Assert-Throws { Enable-DisplayWorkaround -SpotifyDirectory $data -DataDirectory $data -NoLaunch } 'Apply requires an installation containing Spotify.exe.'
    Write-Output "PASS: $script:assertions assertions. Spotify was not launched or modified."
} finally {
    $resolved = (Resolve-Path -LiteralPath $testRoot).Path
    $temp = [IO.Path]::GetTempPath().TrimEnd('\') + '\'
    if (!$resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^spotify-workaround-test-[a-f0-9]{32}$') {
        throw 'Unexpected test cleanup path.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
