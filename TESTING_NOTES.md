# Superclip — Testing Notes

## 1. Persistent Clipboard History

### What Changed
- Clipboard history now saves to `~/Library/Application Support/Superclip/history.json`
- Auto-saves with 1.5s debounce after any change
- Loads on app launch
- Flushes immediately on quit

### Test Cases

**Basic Persistence:**
1. Launch app, copy several items: plain text, a URL, an image, a file
2. Quit the app completely (not just close drawer)
3. Relaunch — verify all items are present with correct types and content
4. Check timestamps are preserved

**Pinboard Persistence:**
1. Pin an item to a pinboard
2. Quit and relaunch
3. Verify pinboard still shows the pinned item (pinboard references use item UUIDs, which must survive restart)

**Clear on Quit:**
1. Open Settings > Storage > enable "Clear on quit"
2. Copy a few items, quit the app
3. Relaunch — history should be empty
4. Verify `~/Library/Application Support/Superclip/history.json` is deleted

**History Size Limit:**
1. Set max history to 25 in Settings > Storage
2. Copy 30+ items
3. Quit and relaunch — verify only 25 items are loaded

**Deduplication After Reload:**
1. Copy "hello", quit, relaunch
2. Copy "hello" again — should move to front, not create duplicate

**Undo:**
1. Copy items, delete one with backspace
2. Cmd+Z to undo — item should come back
3. Note: undo is session-scoped, does NOT survive restart (expected behavior)

**Link Metadata:**
1. Copy a URL (e.g., https://github.com)
2. Wait for link preview to load
3. Quit and relaunch — URL item should re-fetch its link preview metadata on load

---

## 2. Configurable Global Hotkeys

### What Changed
- All 3 global hotkeys are now configurable in Settings > Shortcuts
- Interactive hotkey recorder with validation
- Persisted in UserDefaults, applied immediately

### Test Cases

**Change a Hotkey:**
1. Open Settings > Shortcuts
2. Click the hotkey field next to "Open clipboard history"
3. Field should show "Press shortcut..." with orange highlight
4. Press a new combo (e.g., Cmd+Shift+P)
5. Field should update to show the new combo
6. Press the new combo — clipboard history should open
7. Press the OLD combo (Cmd+Shift+A) — should NOT work anymore

**Validation - No Modifier:**
1. Click a hotkey field to start recording
2. Press just a letter key (e.g., "P" with no modifiers)
3. Should show error: "Add a modifier key (⌘, ⌃, or ⌥)"
4. Hotkey should NOT change

**Validation - Conflict Detection:**
1. Set clipboard history hotkey to Cmd+Shift+A (default)
2. Try to set paste stack hotkey to Cmd+Shift+A as well
3. Should show error: "Conflicts with another shortcut"
4. Paste stack hotkey should NOT change

**Cancel Recording:**
1. Click a hotkey field to start recording
2. Press Escape
3. Recording should cancel, original shortcut remains

**Reset to Defaults:**
1. Change all 3 hotkeys to custom combos
2. Click "Reset to Defaults"
3. All 3 should revert to: ⌘⇧A, ⌘⇧C, ⌘⇧`

**Persistence:**
1. Change a hotkey to a custom combo
2. Quit and relaunch
3. Open Settings > Shortcuts — custom combo should still be set
4. Press the custom combo — should work

**Quit & Reset:**
1. Change hotkeys, then use About > "Quit & Reset"
2. Relaunch — hotkeys should be back to defaults (all UserDefaults cleared)

---

## 3. Smart Collections / Auto-Tagging

### What Changed
- Clipboard items are now auto-tagged with content sub-categories (color, email, phone, code, JSON, address)
- New `ContentDetector.swift` with regex-based detection — runs on copy, no external APIs
- Tags stored as `detectedTags: Set<ContentTag>` on `ClipboardItem`, persisted via `CodableClipboardItem`
- Filter bar (horizontal pill buttons) above the card list for filtering by type
- Tag badges displayed in the card header

### Test Cases

**Color Detection:**
1. Copy `#FF5733` → card should show "Color" tag badge in header
2. Copy `rgb(255, 87, 51)` → should show color tag
3. Copy `hsl(9, 100%, 60%)` → should show color tag
4. Copy `#abc` (3-char hex) → should show color tag
5. Copy plain text "hello" → should NOT show color tag

**Email Detection:**
1. Copy `user@example.com` → should show "Email" tag badge
2. Copy `first.last+tag@company.co.uk` → should show email tag
3. Copy `not-an-email` → should NOT show email tag

**Phone Detection:**
1. Copy `+1 (555) 123-4567` → should show "Phone" tag badge
2. Copy `+44 20 7946 0958` → should show phone tag
3. Copy `123` → should NOT show phone tag (too few digits)

**Code Detection:**
1. Copy a multi-line Swift snippet (func, braces, indentation) → should show "Code" tag badge
2. Copy a Python snippet (def, indentation) → should show code tag
3. Copy a JS snippet (function, const, =>) → should show code tag
4. Copy a single line of text → should NOT show code tag

**JSON Detection:**
1. Copy `{"key": "value", "count": 42}` → should show "JSON" tag badge
2. Copy `[1, 2, 3]` → should show json tag
3. Copy `{invalid json` → should NOT show json tag
4. Copy plain text starting with a letter → should NOT show json tag

**Address Detection:**
1. Copy `123 Main Street` → should show "Addr" tag badge
2. Copy `456 Oak Ave` → should show address tag
3. Copy `hello world` → should NOT show address tag

**Multiple Tags:**
1. Copy text containing both an email and a phone number → should show both tag badges

**Filter Bar:**
1. Open drawer → filter bar with pill buttons visible above card list
2. "All" is selected by default → all items shown
3. Click "Colors" → only items with color tag shown
4. Click "Links" → only URL-type items shown
5. Click "Images" → only image-type items shown
6. Click "Code" → only code-tagged items shown
7. Click active filter again → deselects, returns to "All"

**Filter + Search:**
1. Select "Colors" filter, then type in search → both filters applied simultaneously
2. Clear search → still filtered by "Colors"
3. Click "All" → search still applied, filter cleared
4. Clear search → all items shown

**Filter + Pinboard:**
1. Switch to a pinboard → filter bar still works
2. Select a filter → pinboard items filtered accordingly

**Persistence:**
1. Copy items with various tags, quit and relaunch
2. Tags should persist — color/email/code badges should still appear
3. Filter bar should still work on reloaded items

**Keyboard Navigation:**
1. Apply a filter, use arrow keys → navigation works within filtered results
2. Apply filter that shows 0 results → empty state message shown
3. Change filter → selection resets to first item

**Don't Break:**
- Existing search still works independently
- Card layout unchanged (tags are small badges in header)
- Pinboard filtering unaffected
- Drag and drop still works
- Context menu still works
- Hold-to-edit still works

---

## 3. Quick Actions Per Content Type

### What Changed
- New `QuickActions.swift` with content detection (regex-based) and context-aware actions
- Preview panel (Space) shows a "Quick Actions" bar with relevant action buttons
- Right-click context menu on cards includes a "Quick Actions" submenu
- Detected content types: Color Hex, URL, JSON, Email, Phone, Code, File Path

### Test Cases

**Color Hex:**
1. Copy "#FF5733" to clipboard
2. Open Superclip, press Space to preview
3. Preview should show a color swatch (orange-red rectangle) + RGB value text
4. Click "Copy as RGB" → clipboard should contain "rgb(255, 87, 51)"
5. Click "Copy as HSL" → clipboard should contain "hsl(11, 100%, 60%)" (approx)
6. Right-click the card → Quick Actions submenu → "Copy as RGB" works the same

**URL with Tracking Params:**
1. Copy "https://example.com?utm_source=twitter&utm_medium=social"
2. Preview → Quick Actions bar shows "Open in Browser" and "Copy Clean URL"
3. Click "Copy Clean URL" → clipboard should contain "https://example.com"
4. URLs without tracking params should NOT show "Copy Clean URL"

**JSON:**
1. Copy messy JSON, e.g. `{"name":"test","value":123}`
2. Preview → "Pretty Print" button → clipboard has indented/formatted JSON
3. "Minify" button → clipboard has compact single-line JSON
4. "Copy as String" → clipboard has escaped JSON string

**Email:**
1. Copy "user@example.com"
2. Preview → "Compose Email" → opens default mail app with mailto: link
3. "Copy Address" → clipboard has "user@example.com"

**Phone Number:**
1. Copy "+1 (555) 123-4567"
2. Preview → "Call via FaceTime" → opens FaceTime with the number
3. "Copy Digits Only" → clipboard has "+15551234567"

**Code:**
1. Copy indented code (e.g. a Swift function with 4-space indent)
2. Preview → "Copy Without Indentation" → clipboard has code with leading whitespace stripped
3. "Wrap in Code Block" → clipboard has code wrapped in ``` markers

**File Path:**
1. Copy "/Users/username/Documents/file.txt"
2. Preview → "Open in Finder" → reveals file in Finder
3. "Copy Filename Only" → clipboard has "file.txt"
4. "Copy Parent Directory" → clipboard has "/Users/username/Documents"

**Context Menu Integration:**
1. Right-click any card with detected content → "Quick Actions" submenu appears with relevant actions
2. Right-click a plain text card (no patterns) → no "Quick Actions" submenu

**No False Positives:**
1. Copy plain text like "Hello world" → no quick actions shown in preview or context menu
2. Copy an image → no quick actions (only text-based items are analyzed)
