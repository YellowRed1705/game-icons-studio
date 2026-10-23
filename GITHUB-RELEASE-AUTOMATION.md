# One-click GitHub Release workflow

This workflow is intentionally manual: it does not publish anything merely because code is pushed. The maintainer chooses when the release is ready.

## One-time setup

1. Merge/copy this source update into your local clone of `YellowRed1705/game-icons-studio`.
2. Review changes, then commit and push the source update and `.github/workflows/publish-release.yml` to `main`. GitHub can only run the workflow after it exists on the default branch.
3. In GitHub, open Settings → Actions → General and ensure workflow permissions allow the `GITHUB_TOKEN` to write repository contents. The workflow explicitly requests `contents: write` and `issues: write`; organization policy may still restrict these permissions.

## For each future release

1. Develop and test the code, increment all app version labels, and add `CHANGELOG-vX.Y.md` to the same commit on `main`.
2. Open Actions → Publish Game Icons Studio Release → Run workflow.
3. Enter the numeric version exactly as in `README.md`, the launcher, app version metadata, and `CHANGELOG-vX.Y.md` (example: `6.35`, without `v`).
4. Leave `reply_to_issues` off for ordinary releases. Turn it on only when the two prepared issue replies should be posted. The workflow uses hidden markers to avoid posting the same version's reply twice.
5. Run the workflow. It validates the version and confirms the tag is unused, builds clean full and overlay-upgrade archives, publishes the GitHub Release, attaches both ZIPs and SHA256 checksums, and optionally comments on issues #1 and #2.

## Packaging safety

The build script uses an explicit allow-list of application files. It does not package settings, API keys, per-user caches, generated icons, logs, history, restore-point backups, or downloaded artwork. The upgrade archive contains all runtime files at archive root so extracting it directly over an existing program folder updates/merges the app without overwriting runtime user data.

The workflow does not close issues automatically. It only posts comments when explicitly enabled. If commenting needs a retry after a release, use Actions → Reply to Game Icons Studio Feature Issues and enter the published version; the helper verifies that release and skips duplicate replies. If the release succeeds but issue commenting needs a retry, use Actions → Reply to Game Icons Studio Feature Issues and enter the already-published version; the helper verifies the release and skips duplicate replies.
