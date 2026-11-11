# Game Icons Studio v6.42 — per-browser API key storage and matching-flow repair

## API key storage and privacy
- Browser mode no longer reads an API key from `settings.json`; it starts with an empty server-side key context.
- The setup UI validates the entered SteamGridDB API key and stores it only in that browser profile's `localStorage` under `gis-sgdb-api-key`.
- Each local API request supplies the saved key through the `X-GIS-API-Key` request header. The server keeps it only in process memory and never writes it to disk.
- Existing `settings.json` files are migrated automatically: the legacy `ApiKey` property is removed and the sanitized settings file is saved. Users with a previous disk-stored key may need to enter it once in the browser.
- Classic CMD mode prompts for an API key for the current run and does not persist it.
- The API key input is masked. The setup screen explains that localStorage is the persistent store and the key is not sent to GitHub.

## No-key mode and artwork matching
- Corrected the no-key setup path so it is deliberately limited to Program & App Icons / Google Images / Yandex Images workflows.
- Game-library, game-folder, folder-icon and standard shortcut artwork matching now require a validated key. Browser entry points and backend scan endpoints enforce this requirement.
- A stored key is revalidated against SteamGridDB on each app launch. Invalid/revoked keys are cleared from browser localStorage and the setup screen is shown again rather than silently producing Placeholder-only results.

## Repository and release protection
- Added ignore patterns for local settings, environment files and API-key text exports.
- Release archives continue to use the explicit runtime allow-list and do not include `settings.json`, caches, user content or credentials.
- No user's API key is part of this source update or GitHub commit.

## Upgrade
- Full package: `Game-Icons-Studio-v6.42.zip`.
- Existing installation: close Game Icons Studio and extract the Upgrade ZIP over the existing application folder. Keep the user data folders; the next run removes the legacy key field from `data/settings.json` and prompts for the key to be saved in the browser profile.
- Browser localStorage is scoped to the browser profile and site origin. Clearing site data or changing the local server port/browser profile requires entering the key again.
