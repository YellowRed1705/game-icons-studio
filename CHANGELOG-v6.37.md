# Game Icons Studio v6.37 — Live operation progress

## Real progress in the browser

- Removed the timer-driven fake progress bar from the apply screen.
- Streams live progress events directly from the actual PowerShell icon pipeline to the browser while work continues.
- Displays real completed/total counts and calculated percentage for artwork downloads (for example, 57 / 59 · 96%), plus the most recently processed cover.
- Adds phase progress for cover downloads, multi-size ICO generation, safety restore-point creation, shortcut updates, and Windows Explorer refresh.
- The displayed percentage is the progress of the current phase. Download counts advance when each whole image finishes or fails; the UI does not pretend to measure bytes downloaded.
- Reports restore-point failures clearly and does not describe a safety-stopped operation as successful.
- Adds live progress labels and accessible progress-bar values to the existing Aurora Glass-friendly loading card.

## Release validation and automation

- Validates the browser JavaScript with Node before release packaging.
- Parses all PowerShell runtime modules and release scripts before publishing.
- Keeps automatic releases tied to adding a new `CHANGELOG-vX.Y.md` file on `main`.
- Publishes the clean full ZIP, overlay-upgrade ZIP, and SHA-256 checksum manifest. Automatic releases do not post issue replies.

## Existing functionality retained

- Game shortcut matching and review-before-apply.
- Program/application icon matching, Iconify candidate discovery, and best-effort Google/Yandex image search.
- Local image selection, drag-and-drop, clipboard paste, and image URL input.
- Multi-size Windows ICO generation and folder icon customization.
- Restore points with configurable retention and existing themes.

## Upgrade

For an existing installation, download `Game-Icons-Studio-v6.37-Upgrade.zip` from the release and extract its contents directly over the current program folder. Settings, API keys, caches, downloaded artwork, generated icons, logs, history, and restore-point backups are excluded from the distribution archive.

The browser now reports operation progress from the real processing pipeline. Remote image load time can still vary with network conditions and the artwork CDN.
