# Game Icons Studio v6.39 — Game Library, launcher conversion and repair

## Game Library Folder (primary workflow)

- Makes Game Library Folder the primary home-screen action and keeps the legacy Shortcuts Only mode separate.
- Recursively inspects existing Windows .lnk links, recognized .url launchers, .exe files, .bat/.cmd scripts and supported emulator ROM formats.
- Uses LiteralPath and Force during folder discovery so hidden entries and paths containing wildcard characters are enumerated correctly.
- Filters the recursive file stream to supported shortcut, launcher, executable, script and ROM extensions before materializing the result list, reducing memory use in large game folders.
- Reuses existing shortcuts and checks their file targets/arguments before creating companions, reducing duplicate game links.
- Filters common installer, uninstaller, crash reporter, anti-cheat and redistributable helpers; also skips common launcher/emulator utility applications from game matching when their shortcut has no game arguments.
- Caps a folder scan at 1,000 launchable entries and reports entries left untouched above the safety limit.

## Launcher links and ROM launch behavior

- Reads Internet Shortcut files and recognizes Steam, Epic Games, Ubisoft Connect, Battle.net, EA, Xbox and other registered Windows URL protocol handlers.
- Converts recognized .url launchers to standard .lnk shortcuts that delegate the URI to Windows Explorer and its registered protocol handler.
- Keeps the original .url source until the replacement shortcut has passed launch-URI verification, a restore transaction has captured the source, and the custom icon has been saved.
- Adds ROM discovery for common Game Boy, GBA, DS, 3DS, N64, NES, SNES, Mega Drive, Wii/GameCube, Wii U, Switch and disc-image formats.
- Detects emulator executable shortcuts already present in the selected folder and uses supported launch profiles for Cemu, Ryujinx/Eden/Yuzu, Dolphin, mGBA, melonDS, Azahar/Citra and PCSX2.
- When a matching emulator shortcut is not present, a ROM companion .lnk uses the registered Windows file association rather than guessing an emulator path.
- Source EXE, BAT, CMD and ROM files remain untouched; companion Windows shortcuts are created as needed.

## Modern Windows file and folder dialogs

- Replaces the legacy WinForms FolderBrowserDialog/OpenFileDialog with the native Windows Common Item Dialog (IFileOpenDialog), providing the modern Explorer-style picker on Windows 10/11.
- Keeps the picker asynchronous to the browser so the local web server can continue responding while the native dialog is open.
- Adds a Windows CI compile check for the native dialog COM declarations.

## Persistent icons, Undo and repair

- Validates ICO directory headers before assigning a custom icon and verifies the saved .lnk still retains its launch target, arguments and working directory.
- Stores and references the generated multi-size ICO files from the persistent Icons folder; existing runtime artwork/settings folders are preserved by overlay upgrades.
- Adds Undo Last Change to restore the latest unused icon transaction with one action.
- Makes converted URL launchers fully reversible: Undo removes a newly created .lnk and restores the original .url file from the transaction backup.
- Adds Repair Broken Icons. It scans .lnk icon references, relinks valid ICOs from the persistent Icons folder, rebuilds missing ones from matching local artwork in Cache when available, and refreshes Windows Explorer's icon cache.
- Reports unresolved icons when their ICO and matching cached source artwork are both missing; those entries need a fresh artwork match.

## Regression checks

- Adds Windows CI coverage for native dialog type compilation, launcher URI recognition, .url-to-.lnk conversion, ROM-to-emulator shortcut target/arguments, persistent ICO assignment, shortcut folder health counts, URL source restoration and removal of newly generated links during Undo.
- Release publishing is gated on browser JavaScript syntax, PowerShell parsing, and the Windows shortcut compatibility tests.

## Upgrade

For an existing installation, download Game-Icons-Studio-v6.39-Upgrade.zip from the release and extract its contents directly over the current program folder. The overlay package excludes user settings, API keys, ICO artwork, raw caches, history, logs and restore-point backups so those files remain in place.
