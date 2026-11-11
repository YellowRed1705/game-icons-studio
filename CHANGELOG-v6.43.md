# Game Icons Studio v6.43 — emulator app shortcuts receive artwork

## Root cause
The Game Library folder scanner deliberately excluded existing emulator launcher shortcuts when their command-line arguments were empty. It kept their executable targets for ROM launching, but skipped the shortcuts themselves before the artwork scan. This left Cemu, Eden and Ryubing showing their old small embedded executable icons while normal game shortcuts were updated.

## Fix
- Add a shared emulator-launcher classifier for Cemu, Eden, Ryujinx/Ryubing, Yuzu, Dolphin, mGBA, melonDS, Azahar, Citra and PCSX2.
- Include plain emulator application .lnk shortcuts in Game Library artwork matching instead of discarding them as launcher utilities.
- Keep emulator shortcuts with non-empty command-line arguments classified as game/ROM launch shortcuts.
- Add Ryubing as a Ryujinx-family profile for Switch ROM launch associations.
- Route only detected emulator application entries through the existing Program & App Icons search path (SteamGridDB software icons, Google/Yandex image candidates and embedded executable icon fallback).
- Keep regular game shortcuts in the existing SteamGridDB game-artwork path.
- Carry per-item icon type through review and apply. Unmatched emulator apps are skipped safely rather than receiving fake game Placeholder artwork.
- Preserve the emulator executable map for ROM companion Shortcut creation; no existing launch target or arguments are rewritten by discovery.
- Add Windows CI tests that create actual .lnk files for Cemu, Eden and Ryubing and verify ROM-launch links are not misclassified.

## Upgrade
- Full package: Game-Icons-Studio-v6.43.zip.
- Existing installation: close Game Icons Studio and extract the Upgrade ZIP over the existing application folder.
- Run Game Library Folder again. Cemu, Eden and Ryubing will now be processed as application icons while games retain their normal artwork flow.
