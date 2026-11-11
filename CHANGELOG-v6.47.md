# Game Icons Studio v6.47 — direct image search and streamlined drag-and-drop

## Manual Google Images and Yandex Images
- Removes the unreliable automatic Top 5 fetch interface and its provider-specific result scraping.
- Removes automatic Google/Yandex image collection during Program & App icon scans. Scanning no longer performs background image searches.
- Keeps Google Images and Yandex Images as two separate, clearly visible buttons in the first custom icon editor screen.
- Clicking either provider button opens its image search in a new browser tab and highlights the app's drop area so the image can be dragged straight back into Game Icons Studio.
- Keeps local image selection, clipboard image paste (Ctrl+V), direct image URL loading and the existing custom-image workflow.

## Compact custom icon editor
- Hides the empty crop editor until an image has actually been loaded.
- Keeps the drop area and square icon preview visible at the top of the editor, without requiring a scroll just to drop an image.
- Uses a responsive layout for compact desktop windows and smaller screens.
- Shows the crop editor automatically after an image is dropped, pasted, selected locally or loaded from a URL.

## Safe application-icon fallback
- Program scans no longer scrape third-party image pages in the background.
- The embedded application icon remains the safe default until the user selects a replacement.
- Custom images still use the shared ICO conversion and CornerRadius / Border / Shadow styling pipeline.
- Manual image search and custom image selection do not require a Google, Yandex or SteamGridDB API key.

## Upgrade
- Full package: `Game-Icons-Studio-v6.47.zip`.
- Existing installation: close Game Icons Studio and extract `Game-Icons-Studio-v6.47-Upgrade.zip` over the existing program folder.
