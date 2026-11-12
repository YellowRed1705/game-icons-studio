# Game Icons Studio v6.49 — remembered choices, new-file scanning and reliable icon writes

## Remembered artwork is now the default
- Each scan automatically loads the exact previously selected artwork when its saved source is still available.
- The remembered cover/icon is inserted into the current candidate list and selected before confirmation or automatic matching.
- The review grid displays the actual selected cover, and users can still select one or more items and manually replace the artwork.
- The normal scan no longer stops at a separate "Use my previous choices" prompt.
- The "Start over" / ignore-memory behavior no longer deletes `choices.json`; it only ignores saved picks for the current scan.

## Only-new file and shortcut scans
- Adds a path-based inventory per folder and scan mode. Same-named new shortcuts are detected because full paths, not normalized names, are compared.
- Game Library mode tracks `.lnk`, `.url`, `.exe`, `.bat`, `.cmd` and supported emulator ROM extensions.
- Shortcuts Only mode tracks `.lnk` paths independently of Game Library mode.
- When new items are detected, the UI offers **Only new files / shortcuts** or **Scan everything**.
- Game Library only-new scans still inspect existing emulator launcher shortcuts to build correct ROM launch commands, while only new targets enter the update queue.
- The path inventory is saved after the apply attempt, not at scan start. A scan cancelled before apply does not consume new items; failed paths remain eligible for a later scan.
- An explicit inventory-baseline flag prevents a race between the count prompt and scan from reverting an empty new-item set to a full-folder scan.
- Existing v6.48 `knownGames.json` data is retained as a one-time migration fallback.

## Single-item editing and shortcut write reliability
- Fixes the review-grid edit queue: Auto mode is disabled while the user manually edits selected items, so a single selected icon cannot be auto-accepted or skipped.
- Resets manual picker state when starting a selected-files scan, preventing a previous scan's Auto/program state from leaking into a one-shortcut operation.
- Shortcut icon writes now use a fresh `WScript.Shell` COM instance per attempt, release COM references, retry transient lock/sync failures, and verify the persisted `IconLocation`.
- Preserves TargetPath, Arguments, WorkingDirectory and original read-only attributes. Up to four attempts are made before an item is reported as failed.
- Adds Windows regression checks for same-folder path inventory, old data compatibility, one-item selection and repeated icon writes.

## Upgrade
- Full package: `Game-Icons-Studio-v6.49.zip`.
- Existing installation: close Game Icons Studio and extract `Game-Icons-Studio-v6.49-Upgrade.zip` over the existing program folder.
- Existing `choices.json`, `overrides.json`, `knownGames.json`, cache, icons, logs and restore history remain local and are not included in the upgrade archive.
