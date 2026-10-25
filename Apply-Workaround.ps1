param([string]$SpotifyDirectory, [string]$DataDirectory, [switch]$CloseSpotify, [switch]$NoLaunch)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'src\SpotifyDisplayWorkaround.psm1') -Force
    Enable-DisplayWorkaround @PSBoundParameters
} catch { Write-Error $_; exit 1 }
