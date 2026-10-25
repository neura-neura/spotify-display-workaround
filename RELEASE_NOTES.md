# v1.0.0

Initial release of a reversible Windows workaround for display dropouts when Spotify starts.

## Included

- Apply and restore launchers with English prompts.
- PowerShell scripts for the standalone Spotify desktop installation.
- Local backup of the original Widevine folder and checks that refuse unexpected content.
- Isolated tests for backup, restore, and refusal behavior.
- A portable ZIP and SHA-256 checksums. Extract the whole ZIP before running a launcher.

## Behavior

Applying the workaround closes Spotify, moves its downloaded `WidevineCdm` folder to a local backup, creates an empty read-only placeholder, and reopens Spotify. Restoring recovers the original folder. Neither action requires a Windows restart or changes display modes or global HDCP settings.

## Limitations

Protected video inside Spotify may stop playing. Music playback worked in the initial manual checks, but compatibility is not guaranteed. The Microsoft Store installation is not supported automatically. Updates may replace the workaround.

The initial checks verified that Widevine was absent after two launches, playback advanced, and the display mode stayed stable on one Windows 11 PC. Hardware acceleration had already been disabled separately. The original first-launch-after-boot failure was not reproduced, so this release does not claim a confirmed root cause or a universal fix.

The scripts are unsigned. No Spotify binaries, personal logs, account data, or local backups are distributed.
