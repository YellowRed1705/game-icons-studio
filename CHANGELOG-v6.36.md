# Game Icons Studio v6.36 — Faster cover previews

## Performance improvements

- Replaced eager loading of every alternate cover with a progressive, prioritized thumbnail queue.
- Prioritizes the selected cover and nearby visible thumbnails first.
- Limits the cover picker's active thumbnail loads to four at a time to reduce bursts of competing image requests.
- Uses viewport observation to defer off-screen cover images until they approach the visible area.
- Preloads only the primary cover for the current item instead of preloading every alternative and future candidates.
- Cancels queued and active cover-preview work when leaving the picker, helping the next screen remain responsive.
- Uses asynchronous image decoding and a visual loading state while thumbnails arrive.

## Release automation

- Added automatic release publishing when a new `CHANGELOG-vX.Y.md` file is added to `main`.
- The workflow validates version consistency and JavaScript syntax before packaging.
- Publishes the clean full ZIP, overlay-upgrade ZIP, and SHA-256 checksum manifest.
- Manual publishing remains available. Feature-request issue replies stay opt-in and are not posted by automatic releases.

## Existing functionality retained

- Game shortcut artwork matching and review-before-apply workflow.
- Program/application icon matching, Iconify candidates, and best-effort Google/Yandex image discovery.
- Local image selection, drag-and-drop, clipboard paste, and image URL input.
- Multi-size Windows ICO generation and folder icon customization.
- Restore points with configurable retention, theme options, and the Aurora Glass default.

## Upgrade notes

For existing installations, download `Game-Icons-Studio-v6.36-Upgrade.zip` from the release and extract its contents directly over the current application folder. Settings, API keys, caches, downloaded artwork, generated icons, logs, history, and restore-point backups are excluded from the distribution archive.

The change is designed to improve responsiveness when choosing alternate covers. Actual load time still depends on the network and the artwork CDN, so inaccessible or slow remote images may continue to take longer.
