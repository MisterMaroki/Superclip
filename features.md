# Superclip — Features

Global:
hotkeys:
open panel - cmd+shft+a
open paste stack - cmd+shft+c
screenshot (area / window / full screen) - cmd+shft+4
capture full screen now - cmd+shft+3
text sniper (ocr) - cmd+shft+`
paste (simulate) - cmd+v

Panel:
hotkeys:
close panel - esc / cmd+shft+a
navigate items - arrow left/right
navigate pinboards - cmd+arrow left/right
search - type any single character
in searching state:
filter by type - pills under the header (links, images, files, code, colors, emails, json, phones)
clear search and filter - esc

buttons:
search - focuses search
pinboards - row of pinboard buttons
plus button - create new pinboard
ocr button - start ocr screen capture
three dot menu - open context menu

Context Menu:
about superclip
settings
quit

Cards:
hotkeys:
open preview - space
open edit - hold space
copy (drawer stays open) - cmd+c
paste - enter (when focused)
paste as plain text - shift+enter
quick paste - cmd+1-9, cmd+0
delete - backspace (inside a pinboard: unpin)
undo delete - cmd+z
actions:
pin / unpin
open link (if URL)
edit rich text
save image
content tags:
auto-detected badges (color, email, phone, code, JSON, address)
color cards show parsed color tint on background (hex, rgb, hsl)

Paste Stack:
hotkeys:
open paste stack - cmd+shft+c
behaviors:
session-scoped stack: copies made while it is open are queued
auto-advance after each paste (cmd+v)
paste order - oldest first, or newest first (toggle in the header)
click a row to paste that item
remove item - x button on the row
actions:
copy item to clipboard
paste current item
advance to next item

Pinboard:
actions:
pin selected item
unpin selected item
open pinned item
persistence:
pinned items persisted across launches

Preview:
hotkeys:
open/close preview - space / esc
actions:
copy content
edit content
open in source app
save image

Rich Text Editor:
hotkeys:
save - cmd+s
close - esc / cmd+w
actions:
edit RTF
copy rich text
export RTF/plain text

OCR:
actions:
extract text from image
copy OCR text
open OCR result in editor

Image Editor:
actions:
crop
annotate
copy image
save image

Screen Capture:
actions:
capture area
copy capture to clipboard
open capture in image editor

Snippets:
trigger-based text expansion (e.g., ;;email expands to full address)
global keyboard monitoring — works in any app
create, edit, enable/disable snippets in settings
persisted across launches

Quick Actions:
context-aware actions shown in preview panel
color detection: hex (#RRGGBB), rgb(), hsl() — convert between formats
JSON: pretty print, minify, copy
email: compose mailto, copy
phone: call, copy
code: copy
file path: reveal in Finder, copy

Smart Filters:
filter bar with auto-detected content categories
filters: All, Links, Images, Files, Code, Colors, Emails, JSON, Phones
content tagging via regex heuristics (color, email, phone, code, JSON, address)

Fuzzy Search:
ranked results by relevance
scoring: exact > prefix > contains > fuzzy (subsequence)
matches on content, source app name, type label, file names

Integrations:
AppIntents / Shortcuts (expose actions)
link metadata fetching (title, description, favicon)

Persistence & Export:
history with deduplication (size limit in settings, default unlimited)
clearing history keeps pinned items
pinboards persisted across launches
snippets persisted across launches
export/import history, pinboards and snippets (settings > storage)

iCloud Sync (needs setup, see SYNC_SETUP.md):
clips, pinboards and snippets sync between Mac and iPhone through the user's iCloud
off by default on the Mac (settings > general), on by default on the iPhone
copied files do not sync; unpinned clips leave iCloud after 30 days; images over 10 MB sync as details only

iPhone app (SuperclipiOS/):
clipboard, pinboards, snippets, search, share extension

Automation targets:
build & archive + notarize
CI: linting, formatting, tests
export/import user data
appstore packaging (screenshots, metadata)
developer helpers (seed clipboard, open panels)
