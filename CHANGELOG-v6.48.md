# Game Icons Studio v6.48 — PowerShell 7.7 scan stability fix

## Embedded application-icon fallback
- Fixes a crash in the browser-driven Game Library scan when a Program / App item falls back to its embedded EXE/ICO icon.
- The fallback path previously placed a `System.Collections.Generic.List[object]` directly inside an array expression in a hashtable. On PowerShell 7.7 this could throw `System.ArgumentException: Argument types do not match` in `Step-WebScan`.
- Materializes the fallback list with `ToArray()` before constructing the JSON section, so the browser receives a normal array of artwork candidates.
- Keeps available SteamGridDB alternatives in the same section and preserves the embedded icon as the first candidate.

## Regression coverage
- Adds a compatibility test for the exact Generic.List-to-array conversion used by the fallback.
- Verifies the resulting section survives JSON serialization and deserialization.
- Keeps the existing Windows picker, emulator shortcut, launcher conversion, ICO persistence and Undo regression checks.

## Upgrade
- Full package: `Game-Icons-Studio-v6.48.zip`.
- Existing installation: close Game Icons Studio and extract `Game-Icons-Studio-v6.48-Upgrade.zip` over the existing program folder.
- The upgrade overlay replaces runtime files only; local settings, API-key browser storage, saved choices, artwork cache and restore history are not included in the archive.
