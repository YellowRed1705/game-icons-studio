# Game Icons Studio v6.41 — UI recovery and reliable window focus

## Browser UI recovery
- Fixed malformed JavaScript object syntax across the English, Turkish and Arabic operational-message dictionaries.
- Restored parsing of the full browser script. The syntax error stopped the entire script from loading, which left all inline button actions inert.
- Removed a malformed duplicate `repairCacheRefreshed` message property and corrected missing property separators and locale object boundaries.
- Verified the extracted browser JavaScript with `node --check`.

## Language selector
- Replaced emoji flags with bundled inline SVG flags for the United Kingdom, Türkiye and Saudi Arabia.
- SVGs render independently of the Windows emoji font and are sized explicitly for crisp, consistent display.
- Kept the selector in LTR layout while Arabic app content uses RTL direction.
- Moved remembered language selection to `gis-lang-v3`. A first v6.41 launch defaults to English even when an older browser profile had an Arabic value saved under the previous key. After a user selects a language, that selection persists.

## Windows picker and Explorer focus
- Captures the foreground browser HWND at the time the folder or multi-file picker is requested.
- Passes that real owner handle into the asynchronous STA dialog worker and uses it as the native Common Item Dialog owner.
- Makes the dialog caption watcher tolerant of Windows caption variations while retaining an explicit title match.
- Retains the maximize/foreground helper for native folder/file pickers and post-apply Explorer. Explorer opens in Large Icons view, maximized and focused.

## Upgrade
- Full package: `Game-Icons-Studio-v6.41.zip`.
- Existing installation: close Game Icons Studio and extract the ZIP contents over the existing program folder. Do not delete `Settings`, `Icons`, `Cache`, `Logs`, `History`, or Restore Point data.
- Version 6.41 is a source-level fix. The JavaScript syntax was validated in this environment; actual native Windows window activation should still be confirmed on the target Windows desktop.
