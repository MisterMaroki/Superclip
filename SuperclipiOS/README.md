# Superclip for iPhone

The iPhone companion to Superclip for Mac. Same design language, built for one hand.

## Run it

```bash
xcodegen generate
open SuperclipiOS.xcodeproj
```

Pick an iPhone simulator and run. The app starts empty; choose **Load sample clips** to fill it.

Launch arguments (Scheme > Run > Arguments) for jumping straight to a screen:

| Argument | Effect |
|---|---|
| `-sampleData 1` | Load the sample library |
| `-appearance dark` / `light` | Force an appearance |
| `-screen pinboards` / `snippets` / `detail` / `settings` / `search` | Open on that screen |

## What's here

- **Clipboard**: every clip, newest first. Tap to copy. Swipe right to pin, left to delete (with undo). Search sits at the bottom.
- **Pinboards**: clips you chose to keep, grouped.
- **Snippets**: text you type often; tap to copy.
- **Saving from the clipboard** uses the system paste button, so iOS never interrupts with its "Allow Paste" alert.

## Sharing and sync

- **Share extension**: "Superclip" in the share sheet saves text, links and images. They appear the next time the app opens.
- **iCloud sync** with the Mac app is built in and on by default. It needs the iCloud capability registered on the developer account first; see `../SYNC_SETUP.md`.
