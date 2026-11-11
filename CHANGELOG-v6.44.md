# Game Icons Studio v6.44 — compact language switcher and manual game selection

## Language switcher
- Replaces the always-visible EN/TR/AR flag group with a single compact current-flag button.
- Clicking the flag cycles English → Turkish → Arabic → English.
- Preserves the selected language in this browser's existing `gis-lang-v3` localStorage preference.
- Keeps the current flag accessible with a tooltip and screen-reader label describing the next language.

## Manual game selection
- Adds a direct Change Game action to every regular game tile in the review grid.
- Expands the existing wrong-game screen with a SteamGridDB search field and a dedicated search endpoint.
- Reuses the current browser-local SteamGridDB API key; no API key or secret is added to the repository or release.
- Keeps the scan's built-in alternative matches available before a new search.
- Adds a custom title route for games missing from SteamGridDB. The user can choose cover artwork through Google Images, Yandex Images, a URL, drag-and-drop, clipboard or a local image.
- Saves the custom display title into the selected artwork metadata only. The original Shortcut name, target path, and arguments stay unchanged.
- Adds Windows regression assertions for the new API route, custom title flow, per-item Change Game action and one-flag switcher.

## Upgrade
- Full package: `Game-Icons-Studio-v6.44.zip`.
- Existing installation: close Game Icons Studio and extract `Game-Icons-Studio-v6.44-Upgrade.zip` over the existing application folder.
- Start `Game Icons Studio.bat` and re-scan the folder. Select any tile's Change Game button to open the matching and manual search flow.
