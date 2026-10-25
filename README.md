# Spotify Display Workaround for Windows

A reversible workaround for external monitors that briefly go black, lose signal, or change mode when Spotify starts.

Some users report that Spotify's Widevine component triggers display problems when protected output is initialized. This tool prevents Spotify from loading that component by backing up its `WidevineCdm` folder and putting an empty, read-only file in its place. It does not decrypt protected media or change Windows HDCP settings.

**This is an unofficial workaround, not a confirmed fix for every display problem. Protected videos inside Spotify may stop playing.** If music stops playing or the workaround does not help, restore the original folder.

## Download and apply

1. Download `spotify-display-workaround-v1.0.0-windows.zip` from [Releases](https://github.com/neura-neura/spotify-display-workaround/releases/latest).
2. Extract the entire ZIP to a regular folder. Keep the `src` folder alongside the launchers.
3. Read the scripts, then double-click `Apply-Workaround.cmd` and confirm the prompt.
4. The tool closes Spotify, saves a local backup, applies the workaround, and opens Spotify again. Play a song to check that playback works.

No Windows restart or administrator account is normally needed. Run the tool as your regular Windows user. The launchers use Windows PowerShell with a process-local execution-policy override; they do not change the system execution policy. The scripts are unsigned.

## Restore

Double-click `Restore-Workaround.cmd` and confirm. It closes Spotify, restores the original Widevine folder, and opens Spotify again.

The tool leaves these files in `%LOCALAPPDATA%\Spotify` while applied:

- `WidevineCdm`: an empty, read-only placeholder file.
- `WidevineCdm.backup-<unique ID>`: your original folder, kept intact.
- `spotify-display-workaround.json`: the backup name and state format version.

Keep the backup until you restore. It is local to your installation and is not included in this repository or uploaded anywhere. If another workaround already replaced this folder, this tool refuses to adopt or overwrite it.

## Supported installation

- Windows with Windows PowerShell 5.1 or PowerShell 7.
- The standalone Spotify desktop installation with `Spotify.exe` in `%APPDATA%\Spotify` and downloaded components in `%LOCALAPPDATA%\Spotify`.

The Microsoft Store package, other operating systems, and installations without a downloaded Widevine folder are not supported automatically. Custom directories can be supplied explicitly. The tool checks for `Spotify.exe` but does not certify that a custom installation is compatible.

```powershell
# Close Spotify yourself, then apply without reopening it.
.\Apply-Workaround.ps1 -NoLaunch

# Or explicitly allow the script to close this Spotify installation.
.\Apply-Workaround.ps1 -CloseSpotify

# Restore from the same backup.
.\Restore-Workaround.ps1 -CloseSpotify

# Custom standalone installation and data folders.
.\Apply-Workaround.ps1 -SpotifyDirectory 'D:\Apps\Spotify' -DataDirectory 'D:\Data\Spotify' -CloseSpotify
```

The scripts do not change screen resolution, refresh rate, GPU drivers, hardware acceleration, or global HDCP settings. They do not include Spotify binaries, account information, or diagnostic logs. They make no network requests themselves; Spotify can use the network when reopened.

## Evidence and limits

The initial manual check used Spotify 1.2.92.148 on one Windows 11 PC with an NVIDIA RTX 4070 and three displays. After applying the workaround, two complete Spotify launches showed no loaded `widevinecdm.dll`, a music track's playback counter advanced, and the primary display stayed at 3440 x 1440 at 180 Hz. Hardware acceleration had also been disabled separately on that PC.

The original first-launch-after-boot failure was **not reproduced during those checks**. These observations verify that the workaround applied and that tested playback continued; they do not prove that Widevine caused the original incident, isolate the effect from the earlier acceleration change, or establish that all future launches will be free of flicker. Playback on other tracks, app versions, accounts, and hardware is not guaranteed. An update may replace the placeholder or change how Spotify loads components.

Related primary reports and documentation:

- [Spotify Community: display drops on desktop app launch](https://community.spotify.com/forum/en/discussion/7560058/desktop-app-ms-store-triggers-an-hdcp-handshake-on-every-launch-and-my-external-hdmi-monitor-lose). A user reports the same workaround; this is not an engineering confirmation from Spotify.
- [Mozilla bug 1958685: Widevine and external display blackouts](https://bugzilla.mozilla.org/show_bug.cgi?id=1958685). This report remains unconfirmed.
- [Microsoft: Output Protection Manager](https://learn.microsoft.com/en-us/windows/win32/medfound/using-output-protection-manager). Documents protected output and HDCP; it does not diagnose Spotify.

## Validation

Run the isolated file-operation tests from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Workaround.ps1
pwsh -NoProfile -File .\tests\Test-Workaround.ps1
```

The tests use generated fixtures in a temporary directory. They check backup and restore integrity, repeated apply, missing backups, unexpected placeholder content, invalid paths in saved state, and unmanaged installations. They do not launch Spotify or test a physical display blackout.

Release downloads include `SHA256SUMS.txt`. Compare a download with `Get-FileHash -Algorithm SHA256` before using it. The checksums detect changes relative to the published values; they are not a code-signing certificate.

To build the downloadable package locally, run `.\Build-Release.ps1`. The ZIP and checksums are written to `dist`. Only the listed source files, documentation, and tests are packaged; local Spotify folders and backups are excluded.

## License

MIT. This project is not affiliated with Spotify, Google, Microsoft, or NVIDIA.
