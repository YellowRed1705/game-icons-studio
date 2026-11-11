# Game Icons Studio v6.38 — Game Files Folder workflow

## Restored workflow

- Adds a dedicated **Game Files Folder** option to the home screen for scanning a selected game installation/library folder recursively.
- Finds existing Windows `.lnk` shortcuts, launcher `.url` files, playable `.exe` files, and `.bat`/`.cmd` launchers.
- Reuses existing shortcuts and checks their target/arguments so an EXE already launched by a shortcut does not receive a duplicate companion link.
- Converts eligible `.url` launcher files to standard Windows `.lnk` files after successfully creating the new shortcut. If conversion fails, the original URL file is retained and a companion-link fallback is queued.
- Creates adjacent custom-icon `.lnk` shortcuts for eligible EXE/BAT/CMD files during the normal apply step. Original executable and script files are not modified.
- Filters common installers, uninstallers, crash reporters, anti-cheat helpers, and redistributable setup files from the EXE list.
- Caps the scan at 1,000 launchable entries; additional entries are left untouched and reported in the scan summary.
- Automatically matches discovered entries through the existing SteamGridDB scan and review/apply flow.
- Adds English and Arabic home-screen labels for the new workflow.

## Retained functionality

- The existing Shortcuts Folder, Specific Shortcuts, Any Files & Scripts, Program & App Icons, All Sub-Folders, and Specific Folder options remain available.
- Existing custom cover selection, multi-size ICO generation, restore points, the v6.37 real-time progress display, and existing themes are retained.
- The homepage retains its logo, demo video, and before/after artwork while adding the v6.38 release notes.

## Safety notes

- EXE/BAT/CMD source files are left in place. Windows Explorer receives a companion `(Custom Icon).lnk` file with the original executable/script as its launch target.
- Existing standard `.lnk` files are updated directly, preserving their target, arguments, and working directory.
- A `.url` source is removed only after a standard `.lnk` file has been created successfully. Failed conversions leave the source in place.
- Common setup/helper files are excluded to reduce accidental matches to installers or support tools.

## Upgrade

For an existing installation, download `Game-Icons-Studio-v6.38-Upgrade.zip` from the release and extract its contents directly over the current program folder. Settings, API keys, caches, downloaded artwork, generated icons, logs, history, and restore-point backups are excluded from the distribution archive.
