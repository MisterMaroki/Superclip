# Superclip — Features

Global:
hotkeys:
open panel - cmd+shft+a
copy to clipboard - cmd+c
copy and open in paste stack - cmd+shft+c
paste (simulate) - cmd+v

Panel:
hotkeys:
close panel - esc / cmd+shft+a
navigate items - arrow left/right
navigate pinboards - cmd+arrow left/right
search - type any single character
in searching state:
clear search and stop searching - esc

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
copy - cmd+c
paste - cmd+v / enter (when focused)
delete - backspace
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
session-scoped stack
auto-advance after each paste (cmd+v)
remove item - backspace
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
history (max 100) with deduplication
pinboards persisted across launches
snippets persisted across launches
export/import settings and data (pins, history)

Automation targets:
build & archive + notarize
CI: linting, formatting, tests
export/import user data
appstore packaging (screenshots, metadata)
developer helpers (seed clipboard, open panels)
