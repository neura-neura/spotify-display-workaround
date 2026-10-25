Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SpotifyRoot {
    param([string]$SpotifyDirectory)
    if (!$SpotifyDirectory) { $SpotifyDirectory = Join-Path $env:APPDATA 'Spotify' }
    $item = Get-Item -LiteralPath $SpotifyDirectory -ErrorAction Stop
    if (!$item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'The Spotify directory must be a regular directory, not a link.'
    }
    if (!(Test-Path -LiteralPath (Join-Path $item.FullName 'Spotify.exe') -PathType Leaf)) {
        throw 'Spotify.exe was not found. This tool supports the standalone Windows desktop installation.'
    }
    return $item.FullName
}

function Get-WorkaroundPaths {
    param([string]$SpotifyDirectory, [string]$DataDirectory)
    if (!$SpotifyDirectory) { $SpotifyDirectory = Join-Path $env:APPDATA 'Spotify' }
    $root = Get-SpotifyRoot -SpotifyDirectory $SpotifyDirectory
    if (!$DataDirectory) { $DataDirectory = Join-Path $env:LOCALAPPDATA 'Spotify' }
    $data = Get-Item -LiteralPath $DataDirectory
    if (!$data.PSIsContainer -or ($data.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'The Spotify data directory must be a regular directory, not a link.'
    }
    return [pscustomobject]@{
        Root = $root
        Data = $data.FullName
        Module = Join-Path $data.FullName 'WidevineCdm'
        State = Join-Path $data.FullName 'spotify-display-workaround.json'
    }
}

function Read-WorkaroundState {
    param($Paths)
    $state = Get-Content -LiteralPath $Paths.State -Raw | ConvertFrom-Json
    if ($state.Version -ne 1 -or $state.BackupName -notmatch '^WidevineCdm\.backup-[a-f0-9]{32}$') {
        throw 'The saved workaround state is invalid. No files were changed.'
    }
    return $state
}

function Assert-Placeholder {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer -or $item.Length -ne 0 -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'The Widevine path has changed. Refusing to replace unexpected content.'
    }
    return $item
}

function Stop-ScopedSpotify {
    param([string]$Root, [switch]$CloseSpotify)
    $expected = Join-Path $Root 'Spotify.exe'
    $running = @(Get-Process Spotify -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -eq $expected } catch { $false }
    })
    if ($running.Count -and !$CloseSpotify) {
        throw 'Close Spotify first, or use -CloseSpotify to let the tool close it.'
    }
    if ($running.Count) {
        $running | Stop-Process -ErrorAction Stop
        foreach ($process in $running) {
            if (!$process.WaitForExit(10000)) { throw 'Spotify did not exit. No files were moved.' }
        }
    }
}

function Enable-DisplayWorkaround {
    [CmdletBinding()]
    param([string]$SpotifyDirectory, [string]$DataDirectory, [switch]$CloseSpotify, [switch]$NoLaunch)
    $paths = Get-WorkaroundPaths -SpotifyDirectory $SpotifyDirectory -DataDirectory $DataDirectory
    if (Test-Path -LiteralPath $paths.State) {
        $state = Read-WorkaroundState $paths
        $null = Assert-Placeholder $paths.Module
        if (!(Test-Path -LiteralPath (Join-Path $paths.Data $state.BackupName) -PathType Container)) {
            throw 'The saved backup is missing. No files were changed.'
        }
        Write-Output 'The workaround is already applied.'
        return
    }
    $original = Get-Item -LiteralPath $paths.Module
    if (!$original.PSIsContainer -or ($original.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'WidevineCdm is not a regular folder. An unmanaged workaround may already be present.'
    }
    Stop-ScopedSpotify -Root $paths.Root -CloseSpotify:$CloseSpotify
    $backupName = 'WidevineCdm.backup-' + [Guid]::NewGuid().ToString('N')
    $backup = Join-Path $paths.Data $backupName
    $moved = $false
    $created = $false
    try {
        Move-Item -LiteralPath $paths.Module -Destination $backup
        $moved = $true
        # CreateNew refuses to overwrite content created by another process.
        $stream = [IO.File]::Open($paths.Module, [IO.FileMode]::CreateNew)
        $stream.Dispose()
        $created = $true
        (Get-Item -LiteralPath $paths.Module).IsReadOnly = $true
        [pscustomobject]@{
            Version = 1
            BackupName = $backupName
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath $paths.State -Encoding UTF8
    } catch {
        $failure = $_
        if ($created) {
            $placeholder = Assert-Placeholder $paths.Module
            $placeholder.IsReadOnly = $false
            Remove-Item -LiteralPath $paths.Module
        }
        if ($moved -and !(Test-Path -LiteralPath $paths.Module)) {
            Move-Item -LiteralPath $backup -Destination $paths.Module
        }
        throw $failure
    }
    Write-Output 'Workaround applied. The original Widevine folder is backed up locally.'
    Write-Output 'Protected video inside Spotify may stop playing. Music playback is not guaranteed on every version.'
    if (!$NoLaunch) { Start-Process -FilePath (Join-Path $paths.Root 'Spotify.exe') }
}

function Disable-DisplayWorkaround {
    [CmdletBinding()]
    param([string]$SpotifyDirectory, [string]$DataDirectory, [switch]$CloseSpotify, [switch]$NoLaunch)
    $paths = Get-WorkaroundPaths -SpotifyDirectory $SpotifyDirectory -DataDirectory $DataDirectory
    if (!(Test-Path -LiteralPath $paths.State)) { throw 'No managed workaround was found. No files were changed.' }
    $state = Read-WorkaroundState $paths
    $backup = Join-Path $paths.Data $state.BackupName
    $backupItem = Get-Item -LiteralPath $backup
    if (!$backupItem.PSIsContainer -or ($backupItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'The saved backup is not a regular directory. No files were changed.'
    }
    $placeholder = Assert-Placeholder $paths.Module
    Stop-ScopedSpotify -Root $paths.Root -CloseSpotify:$CloseSpotify
    $placeholder.IsReadOnly = $false
    Remove-Item -LiteralPath $paths.Module
    try { Move-Item -LiteralPath $backup -Destination $paths.Module }
    catch {
        if (!(Test-Path -LiteralPath $paths.Module)) {
            [IO.File]::WriteAllText($paths.Module, '')
            (Get-Item -LiteralPath $paths.Module).IsReadOnly = $true
        }
        throw
    }
    Remove-Item -LiteralPath $paths.State
    Write-Output 'The original Widevine folder has been restored.'
    if (!$NoLaunch) { Start-Process -FilePath (Join-Path $paths.Root 'Spotify.exe') }
}

Export-ModuleMember -Function Enable-DisplayWorkaround, Disable-DisplayWorkaround
