# Game Icons Studio v6.46 — automatic image selection and interactive crop

## Google / Yandex Top 5
- The image search endpoint returns up to five Google Images candidates and up to five Yandex Images candidates in separate arrays.
- Candidate ranking balances the two providers before filling the remaining suggestion list, preventing one provider from occupying the entire result quota.
- The custom editor displays Google and Yandex results in separate Top 5 groups.
- Search starts automatically when the Program / App icon editor opens; a Fetch Top 5 from each button can refresh both providers.
- Each provider candidate supports Fetch & Apply in one click. The local app downloads the original candidate image, decodes it and adds it to the current item. Crop first remains available for manual selection.
- Providers may return fewer than five usable URLs when blocked or when page markup changes; the UI reports the candidates actually found.

## Interactive crop selector
- Adds a source-image canvas to the custom icon editor.
- Drag outside the current square to draw a new square selection; drag inside to reposition it.
- Add Zoom In, Zoom Out and Reset controls. Mouse wheel zoom is supported over the crop stage.
- The selected crop updates the existing square icon preview and produces a square 512 × 512 image.
- The final ICO still runs through the shared application styling pipeline (CornerRadius, Border and Shadow), so custom-cropped icons keep the same shape as other generated icons.

## Privacy and safety
- No Google, Yandex or SteamGridDB API key is added to the repository.
- Image downloads are made by the local desktop app; selected image bytes are saved to the existing local cache before normal Review/Apply.
- Existing restore history and Undo continue to protect the original Shortcut icon state.

## Upgrade
- Full package: `Game-Icons-Studio-v6.46.zip`.
- Existing installation: close Game Icons Studio and extract `Game-Icons-Studio-v6.46-Upgrade.zip` over the existing program folder.
