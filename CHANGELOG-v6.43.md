# Game Icons Studio v6.43 — emulator app shortcuts receive artwork

## Root cause
The Game Library discovery pass excluded any existing emulator shortcut with no command-line arguments. The shortcut was still inspected and retained as a ROM-launch profile, but it never entered the artwork scan. Consequently Cemu/Eden/Ryujinx/Ryubing kept their old embedded executable icons while game shortcuts were updated.

## Fix
- Keep recognized emulator launcher shortcuts in the file list and tag them as Program & App Icons items.
- Preserve the emulator target map so newly generated ROM shortcuts still use the detected executable.
- Add Ryubing as an alias of the Ryujinx emulator family.
- Route only tagged emulator entries through the Program & App Icons matching path (Google/Yandex candidates, software-icon catalogue results and embedded executable fallback). All game entries keep the normal SteamGridDB game-artwork flow.
- Add an item-level icon type to the review/apply payload, so mixed scans save app-icon choices as Kind=icon and do not create a game Placeholder when an app-icon search finds no usable artwork.
- Restore the original overall scan mode when a mixed scan reaches the review grid, while switching the existing editor per selected item.
- Show an explicit count of emulator/application shortcuts queued for Program & App Icons.
- Extend Windows compatibility regression checks for emulator inclusion, per-item mode and the Ryubing alias.

## Release validation
- Rechecked the Ryujinx/Ryubing emulator profile regex after source publication; the PowerShell pattern includes its full end anchor and Switch ROM extensions.

## Validation
- Removed a duplicated trailing copy of the scan/picker helpers that had been left after the first Explorer helper. The final WebServer.ps1 retains one definition of each helper and no orphaned tail text.

## Upgrade
- Full package: Game-Icons-Studio-v6.43.zip.
- Existing installation: close Game Icons Studio and extract the Upgrade ZIP over the existing application folder.
- Re-scan the game library. Cemu/Eden/Ryubing shortcuts will now appear in the Program & App Icons processing path. Existing game icons and ROM launch commands remain unchanged unless you select different artwork.
