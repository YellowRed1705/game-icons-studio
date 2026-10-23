# Automatic and one-click GitHub Release workflow

The release workflow supports automatic publishing and manual publishing. A commit to `main` that adds a new `CHANGELOG-vX.Y.md` starts the release build automatically. Ordinary code edits do not publish a release unless a new version changelog is added. Issue replies are never posted by the automatic path; those remain opt-in.

## One-time setup

1. Merge/copy this source update into your local clone of `YellowRed1705/game-icons-studio`.
2. Review changes, then commit and push the source update and `.github/workflows/publish-release.yml` to `main`. GitHub can only run the workflow after it exists on the default branch.
3. In GitHub, open Settings → Actions → General and ensure workflow permissions allow the `GITHUB_TOKEN` to write repository contents. The workflow explicitly requests `contents: write` and `issues: write`; organization policy may still restrict these permissions.

## For each future release

1. Update the app version labels in the launcher, main banner, web UI, restore-point metadata, and image-search user agent.
2. Add `CHANGELOG-vX.Y.md` and `UPGRADE-INSTRUCTIONS-vX.Y.txt`; update `README.md` to show that version and summarize the change.
3. Commit the release changes to `main`. Adding a new `CHANGELOG-vX.Y.md` automatically triggers validation, clean ZIP builds, SHA-256 generation, and GitHub Release publication.
4. To publish manually instead, open Actions → Publish Game Icons Studio Release → Run workflow and enter the numeric version without `v`.
5. Issue replies remain disabled for automatic releases. Enable `reply_to_issues` only on a manual run when replies should be posted; hidden markers prevent duplicates.

## Packaging safety

The build script uses an explicit allow-list of application files. It does not package settings, API keys, per-user caches, generated icons, logs, history, restore-point backups, or downloaded artwork. The upgrade archive contains all runtime files at archive root so extracting it directly over an existing program folder updates/merges the app without overwriting runtime user data.

The workflow does not close issues automatically. It only posts comments when explicitly enabled. If commenting needs a retry after a release, use Actions → Reply to Game Icons Studio Feature Issues and enter the published version; the helper verifies that release and skips duplicate replies. If the release succeeds but issue commenting needs a retry, use Actions → Reply to Game Icons Studio Feature Issues and enter the already-published version; the helper verifies the release and skips duplicate replies.
