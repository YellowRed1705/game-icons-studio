# Game Icons Studio v6.35

Turn Windows game and application shortcuts into a consistent icon shelf. Game Icons Studio runs locally on Windows 10/11 and supports Windows PowerShell 5.1, with PowerShell 7 recommended.

## Features

- **Smart program icon matching (v6.34):** structured brand-icon search, executable metadata-aware queries, semantic relevance scoring, SVG-to-PNG conversion, and conservative auto-match confidence.

- Match game shortcuts with SteamGridDB and review artwork before applying it.
- Batch-match program/application shortcuts with SteamGridDB plus best-effort Google Images/Yandex Images discovery; rank candidates by square ratio and available resolution, then review all options in one preview grid.
- Search Google Images or Yandex Images in one click. Choose an image from disk, drop it onto the preview, paste it with Ctrl+V, or load it from a URL.
- Convert images into multi-size Windows `.ico` files.
- Customize folder icons through `desktop.ini`.
- For ordinary files that Windows cannot assign a custom Explorer icon to directly (such as `.bat`, `.cmd`, `.ps1`, `.json`, or documents), create a companion `(Custom Icon).lnk` shortcut beside the source; source files are not modified.
- Create restore points before applying changes and restore previous shortcut/folder icon states with configurable retention.
- Use Aurora Glass as the default visual theme; other themes remain available.
- Restore-point dropdown uses theme-safe colors for readable options.

## Install

1. Extract `Game-Icons-Studio-v6.35.zip` to a normal folder.
2. Double-click `Game Icons Studio.bat`.
3. For SteamGridDB game matching, configure a free API key when prompted. Local image selection and embedded executable-icon fallbacks can work without the key.

For an existing installation, close the app and extract the v6.35 Upgrade ZIP directly over the current program folder. The upgrade package preserves your settings and runtime data by not including those files.

## Privacy and clean packaging

The interface is served locally from localhost. The release archive intentionally excludes API keys, user settings, caches, generated icons, logs, history, restore-point backups, downloaded artwork, and development-only files. Runtime settings and data are created as needed. Do not put your personal `data/settings.json` or runtime data into a public release.

Artwork from SteamGridDB and image-search websites is third-party content; review it before applying.

## Version

See [CHANGELOG-v6.35.md](CHANGELOG-v6.35.md).

## License

MIT License. This independent project is not affiliated with SteamGridDB, Valve, Google, Yandex, or any game publisher.


### Smart program-icon search

Program & App Icons now attempts to collect candidates from Google Images and Yandex Images, ranks candidates using available resolution/square-ratio hints, and displays source-labelled previews for one-click selection. Each provider is queried with complementary exact-name and broader branding terms in parallel. Search-result extraction is best-effort because both providers may change or restrict their HTML. Manual search tabs, drag-and-drop, clipboard paste, and local image selection remain available as fallbacks.
