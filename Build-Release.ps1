param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference = 'Stop'
$name = 'spotify-display-workaround-v1.0.0-windows'
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$output = (Resolve-Path -LiteralPath $OutputDirectory).Path
$staging = Join-Path ([IO.Path]::GetTempPath()) ('spotify-release-' + [Guid]::NewGuid().ToString('N'))
$package = Join-Path $staging $name
$null = New-Item -ItemType Directory -Path $package
try {
    $files = @('Apply-Workaround.cmd', 'Apply-Workaround.ps1', 'Restore-Workaround.cmd', 'Restore-Workaround.ps1', 'Build-Release.ps1', 'README.md', 'RELEASE_NOTES.md', 'LICENSE', 'src', 'tests')
    foreach ($file in $files) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $package -Recurse
    }
    $zip = Join-Path $output ($name + '.zip')
    Compress-Archive -LiteralPath $package -DestinationPath $zip -Force
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    ($hash + '  ' + (Split-Path $zip -Leaf)) | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ASCII
    Write-Output $zip
    Write-Output (Join-Path $output 'SHA256SUMS.txt')
} finally {
    $resolved = (Resolve-Path -LiteralPath $staging).Path
    $temp = [IO.Path]::GetTempPath().TrimEnd('\') + '\'
    if (!$resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^spotify-release-[a-f0-9]{32}$') {
        throw 'Unexpected release staging cleanup path.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
