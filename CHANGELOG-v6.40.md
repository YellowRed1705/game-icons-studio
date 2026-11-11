# Game Icons Studio v6.40 — Foreground Windows dialogs and EN / TR / AR

## Maximized and focused Windows pickers

- The native Windows Common Item Dialog now receives the active browser window as its owner instead of being shown without an owner.
- A foreground watcher locates the native picker by its localized caption. It restores the browser owner only if it is minimized, maximizes the picker, temporarily raises it to the topmost position, and brings it to the foreground.
- Folder selection, multi-file selection, and the Icon Repair folder picker all use the same foreground/maximize behavior.
- Native picker captions are localized in English, Turkish and Arabic.

## Post-apply Explorer windows

- After Apply → Finish & open my folder, Game Icons Studio waits for the matching Explorer folder window rather than relying on a fixed startup delay.
- The folder view is set to Large Icons, then the Explorer window is restored, maximized and focused.
- Explorer fallback launches quote folder paths correctly, including paths with spaces.

## Three-language interface

- Replaces the old two-state English/Arabic text toggle with a compact flag selector: 🇬🇧 EN, 🇹🇷 TR and 🇸🇦 AR.
- English is the default language for fresh installations and for profiles that only contain the legacy language preference. New selections are saved using the gis-lang-v2 preference key.
- Adds complete Turkish translations while preserving familiar technical terms in English, including Shortcut, Icon, ROM, Launcher, Preview, Grid, Apply, Restore Point, Cache, History and Review.
- Expands English and Arabic coverage to match the same app screens and operational-message catalogue.
- Translates setup, API-key guidance, home actions, folder modes, launcher conversion, artwork selection, online image candidates, review, report, History, Restore Points, Undo, Icon Repair and progress/error feedback.
- Localizes scan totals, estimated duration, game-library summary counts, repair statistics, theme names, zoom/fullscreen tooltips, retention options and accessibility labels.
- Re-renders visible History, Restore Points, Report, matching, artwork and no-art screens when the language changes, without requiring an app restart.

## Regression checks and packaging

- Extends the Windows regression gate to compile the native foreground/maximize helper and confirm the file/folder dialog uses the active owner and watcher.
- Checks the application source for the three flag buttons, English-first default, localized UI wiring, and the post-apply Explorer maximize/focus path.
- Retains the existing Windows checks for launcher URI conversion, ROM-to-emulator shortcut arguments, ICO persistence, URL-source restoration and generated-shortcut Undo.
- The release gate still checks browser JavaScript syntax and PowerShell parsing before packaging.
- The full and overlay-upgrade ZIPs are built from the same allow-listed runtime sources. User settings, API keys, downloaded artwork, generated ICO files, logs, history, caches and Restore Point backups remain excluded from upgrade archives so an overlay update preserves them.

## Upgrade

For an existing installation, download Game-Icons-Studio-v6.40-Upgrade.zip from the GitHub release and extract its contents directly over the current Game Icons Studio program folder. Close the app first and approve file replacement. Do not delete your existing Settings, Icons, Cache, Logs or restore-history data.
