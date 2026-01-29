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

Integrations:
AppIntents / Shortcuts (expose actions)
link metadata fetching (title, description, favicon)

Persistence & Export:
history (max 100) with deduplication
export/import settings and data (pins, history)

Automation targets:
build & archive + notarize
CI: linting, formatting, tests
export/import user data
appstore packaging (screenshots, metadata)
developer helpers (seed clipboard, open panels)
