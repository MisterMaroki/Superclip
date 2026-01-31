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
