# Game Icons Studio v6.35 — Release automation

## New

- Added a manually triggered GitHub Actions release workflow. It does not publish on every push; a maintainer must deliberately run it from the Actions tab.
- Added a Windows PowerShell build script that creates a clean full ZIP and a complete overlay-upgrade ZIP from an explicit runtime file allow-list.
- Added guardrails for version labels, required files, matching changelog, and unused release tags.
- Release publishing uploads both archives and a SHA-256 checksum manifest.
- Added optional, idempotent replies to feature requests #1 and #2. They are disabled by default, and a separate workflow can safely retry issue replies after a release.
- Distribution packages exclude API keys, user settings, cache files, downloaded artwork, generated icons, logs, history, and restore-point backups.

## Existing app features retained

- Game shortcut artwork matching and review-before-apply flow.
- Program/application icon matching with Iconify brand/software candidates and best-effort Google/Yandex image search.
- Local image selection, drag-and-drop, clipboard paste, and image URL input.
- Multi-size Windows ICO generation, folder icon customization, and restore points with configurable retention.
- Aurora Glass as the default theme and theme-safe restore-point dropdown styling.

## Maintainer setup

See `GITHUB-RELEASE-AUTOMATION.md` in the source-update package. The workflow must first be committed to the repository's default branch. Future releases can then be prepared from **Actions → Publish Game Icons Studio Release → Run workflow**.
