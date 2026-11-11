# Game Icons Studio — Web Modernization Roadmap

**Working branch:** `web-modernization`  
**Roadmap baseline:** v6.39 source tree  
**Status:** Phase 1 — audit and architecture

This roadmap is intentionally incremental. The existing Windows app remains the stable reference implementation until the browser product and its Windows bridge pass acceptance tests. Experimental web work stays on this branch until the full release gate is met.

## Product direction

Build one public, static-first Progressive Web App (PWA) that can be opened from a single HTTPS URL on desktop, tablet and mobile. Keep the UI and product catalogue on the host; keep user artwork, generated ICO files, cache, history and preferences on the user's device by default.

The web app must not pretend that a normal browser tab can edit Windows Shell shortcuts. Windows-specific operations remain an explicitly paired local capability.

## Five phases

### 1. Audit, architecture and icon reliability — current phase

- Map existing PowerShell UI, HTTP endpoints, artwork providers, download/build/apply pipeline, backups and Windows Shell integration.
- Record the browser/OS boundaries and choose a deployment model before migrating features.
- Fix the two high-risk icon reliability patterns found in v6.39: fixed-name ICO overwrites (which can leave Explorer showing an old cached image) and sanitized-name collisions (different item names can collapse to the same file name).
- Make built ICO outputs immutable/content-addressed; update folder `desktop.ini` to point to a content-specific filename instead of rewriting one fixed `folder_icon.ico`.
- Expand Windows CI to verify the new paths, source preservation, and Undo compatibility.
- Deliver this architecture record and test criteria. No production deployment or release tag is made in this phase.

**Exit criteria:** Windows PowerShell parse + JavaScript syntax checks pass; regression tests cover two different ICO contents for one logical name, repeat publishing of identical bytes, folder icon path updates, shortcut target preservation and folder Undo; code remains isolated from `main`.

### 2. Responsive PWA shell and deployment preview

- Create a standalone `web/` static frontend; do not render the complete application HTML from PowerShell.
- Build mobile-first and desktop layouts, automatically selecting a mode from viewport/device capability, with a visible manual Desktop / Mobile override.
- Add fullscreen support, installable PWA manifest, service worker, safe asset versioning and graceful offline shell.
- Keep English, Turkish and Arabic dictionaries with correct RTL behaviour.
- Add a GitHub Actions Pages deployment workflow for preview/production. Start with GitHub Pages because this repository is already public and does not need an additional hosting account. A hosting setting may still need to be enabled once in repository Settings.
- Cloudflare Pages remains a possible later alternative if edge delivery, preview workflows or file limits justify a second hosting account.

**Exit criteria:** one HTTPS preview URL opens on desktop and mobile; manual mode switch works; core shell loads offline after first visit; new commits deploy without asking users to download a ZIP.

### 3. Local-first artwork and rebuild manager

- Use IndexedDB for artwork blobs and metadata, OPFS where large file-oriented caches are useful, Cache Storage for versioned app resources, and localStorage only for small preferences.
- Provide storage estimate / persistence status, quota-aware downloads, cancellation, retry/resume, deduplication and stale-cache cleanup.
- Let the user choose a library or game scope, then run an explicit one-button download/rebuild operation on that device. Do not silently crawl and mirror every provider image.
- Keep source URL, provider, retrieval time and any available attribution/licence metadata beside each item.
- Add asset-pack export/import so a user can move an offline collection between their own devices without requiring a server-side artwork library.

**Exit criteria:** assets are stored locally per browser profile; rebuild works offline for already imported assets; users can export/import a pack; quota and failure states are clear.

### 4. Windows bridge and device-specific capabilities

- Keep the browser application usable on phones without a Windows helper.
- Provide a paired, optional Windows helper for operations that require Windows Shell access: editing `.lnk` IconLocation, writing folder `desktop.ini`, refreshing Explorer and inspecting local folders.
- The bridge must bind to loopback only, require an explicit pairing/one-time token, validate the requesting web origin, expose narrow typed commands, and never provide arbitrary remote command execution or unrestricted filesystem browsing.
- Browser file access must use user-initiated pickers and granted handles. Do not imply that the PWA can silently read or modify a user's disk.
- Clearly label features unavailable on mobile or when the local helper is not paired.

**Exit criteria:** a browser cannot trigger an operation outside the approved bridge API; pairing can be revoked; desktop features work with explicit permission; mobile still supports artwork browsing, previewing and local asset management.

### 5. Hardening, accessibility, deployment and release

- Run automated UI tests at common desktop, tablet and mobile viewports; test RTL, keyboard navigation, contrast and fullscreen.
- Run Windows bridge integration tests on a clean Windows runner and at least one real Windows desktop before calling the migration complete.
- Add CSP/security headers where supported, dependency review, origin checks, safe update rollback, cache migration and backup/restore.
- Review each artwork source's terms and attribution requirements. Keep third-party artwork out of the Git repository and our static hosting unless its licence expressly permits redistribution.
- Publish a stable public URL, installation guide, privacy/storage explanation, Windows helper guide and recovery instructions.

**Exit criteria:** the public URL is stable; a deployment can be rolled back; all security, data-loss and functionality gates pass; release notes describe platform limitations honestly.

## Hosting and data architecture

### Static app

A static PWA is a good fit for GitHub Pages: HTML, CSS, JavaScript, manifest, icons, service worker and version metadata. The hosting service need not receive user artwork. The first deployment target is GitHub Pages; Cloudflare Pages can be evaluated later without moving user data.

### Device storage

- `localStorage`: language, theme, preferred layout and small settings only.
- IndexedDB: artwork blobs, thumbnails, source records, user selections and collection metadata.
- OPFS: larger generated files and working cache when supported.
- Cache Storage: app shell and static resources managed by the service worker.
- Export/import: portable user-owned asset packs.

Browser storage is origin- and browser-profile-specific. Opening the same public URL on another computer creates a separate local collection unless the user exports/imports a pack or deliberately enables a future sync service. Browser storage can be evicted under storage pressure unless persistence is granted; the UI must report status and offer export.

### Windows integration

The PWA and the Windows helper are separate trust boundaries. The web app may request a typed action; the paired local helper performs it after validating origin and pairing. The helper must not turn the public website into a general-purpose remote-control endpoint.

## Copyright and artwork policy

Keeping downloads in local browser storage does **not** automatically make a copyrighted image lawful to copy or use. The safer engineering baseline is:

1. Do not commit provider artwork, game covers or user images to this repository.
2. Do not proxy or re-host third-party artwork by default.
3. Fetch a selected item directly from its provider on the user's device, subject to that provider's current terms and technical access rules.
4. Preserve source and attribution metadata where available.
5. Do not promise zero copyright risk; personal-use exceptions and provider terms depend on jurisdiction, asset and use.
6. If a provider does not allow the requested retrieval or use, do not bypass its restriction.

SteamGridDB v1 API has been deprecated; integrations should be audited against the current API version before the PWA asset manager is built.

## Existing Windows icon issue — initial source audit

The v6.39 pipeline currently writes a logical item's generated ICO to a predictable path derived from a sanitized display name (for example, `Icons/<safe-name>.ico`). Folder icons are similarly copied to the same `folder_icon.ico` path inside the target folder. Sanitization can collapse different names into one file name, and overwriting the same ICO path can leave a shell cache entry associated with the old visual. A successful read-back of `IconLocation` proves that the shortcut points to the intended path; it does not prove that Explorer has rendered the new pixels.

The Phase 1 fix uses content-addressed immutable filenames. Each finished ICO is staged, validated and SHA-256 hashed; its final path includes the hash. Folder `desktop.ini` points at a hash-specific local ICO instead of overwriting one fixed file. Old ICO files remain available for existing references and Undo. Explorer notifications remain in place; a forced Explorer restart is not used for every normal apply.

This is a source-level diagnosis, not proof that every symptom in the supplied screenshots has the same cause. Provider downloads, corrupt source art, invalid ICO entries, permissions, shortcut type and third-party shell caches can still cause individual failures. CI and a real-device test are required before declaring the issue solved.

## Phase 1 regression gates

- Two distinct ICO byte streams using the same logical shortcut name produce distinct final paths.
- Publishing identical ICO bytes twice reuses the same content-addressed path without rewriting it.
- Existing shortcut target, arguments and working directory remain unchanged.
- The stored `IconLocation` references a valid ICO whose file hash matches its path.
- Folder `desktop.ini` references a content-specific local ICO and the file is valid.
- Folder Undo restores the previous `desktop.ini`, previous referenced ICO and folder attributes.
- Existing legacy `folder_icon.ico` installations remain restorable.
- PowerShell parser, extracted browser JavaScript syntax and Windows CI tests pass.

## Decisions intentionally deferred

- Account-based cross-device cloud sync.
- Server-side user libraries or artwork storage.
- Any bulk mirroring of third-party image catalogues.
- A permanent ChatGPT-to-production credential or autonomous write path. Updates should flow through reviewed commits and CI deployment, with repository secrets kept out of the public frontend.
- Forced restart of Explorer on every icon update.
