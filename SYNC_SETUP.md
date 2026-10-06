# Turning on iCloud sync

The sync code is in both apps and is covered by tests, but it has never talked to real iCloud. That needs three things registered on your Apple Developer account, which only you should do (an iCloud container ID can never be deleted once created).

Until these steps are done, both apps run normally. The Mac shows "This build isn't signed for iCloud" if you switch sync on; the iPhone shows "Sign in to iCloud to sync" in the simulator.

## 1. iPhone app

1. `cd SuperclipiOS && xcodegen generate && open SuperclipiOS.xcodeproj`
2. Select the **SuperclipiOS** target, **Signing & Capabilities**, and let Xcode manage signing. The entitlements file already asks for everything; Xcode will offer to register:
   - iCloud container `iCloud.com.omarmaroki.Superclip` (CloudKit)
   - App group `group.com.omarmaroki.Superclip`
   - Push Notifications
3. Do the same for the **SuperclipShare** target (it only needs the app group).
4. Run on a device or a simulator that is signed in to iCloud.

## 2. Mac app

The Mac's entitlements file was deliberately left alone, because adding iCloud to it changes how release builds must be signed.

1. Open `Superclip.xcodeproj`, select the **Superclip** target, **Signing & Capabilities**, **+ Capability**:
   - **iCloud**: tick CloudKit and choose `iCloud.com.omarmaroki.Superclip`
   - **Push Notifications**
2. Run from Xcode, open Settings > General, and switch on **Sync with iCloud**.

### Releases

`scripts/release.sh` signs with Developer ID and no provisioning profile. Once the iCloud capability is on, the release build needs a **Developer ID provisioning profile** that includes iCloud and push. Create it in the developer portal for `com.omarmaroki.Superclip`, then either switch the release build to automatic signing or pass the profile to `xcodebuild`.

## 3. Before shipping to anyone else

- CloudKit creates the record types (`Clip`, `Pinboard`, `Snippet`) in the **development** environment the first time each is saved. In the CloudKit Console, **Deploy Schema Changes** to production before a release build goes out, or production users will not be able to save.
- Change `aps-environment` to `production` for App Store and Developer ID builds (Xcode does this when archiving with automatic signing).

## What to check first

1. Copy something on the Mac; open the iPhone app. It should be there within a couple of seconds.
2. Share a link to Superclip on the iPhone; open the Mac drawer.
3. Delete a clip on one device; it should disappear on the other and not come back.
4. Copy the same text on the Mac with Universal Clipboard on, then open the iPhone app and tap Paste in the banner. There should be one card, not two.
5. Pin different clips to the same pinboard on each device while one is offline. Both pins should survive.

## How it works

- Shared code: `Superclip/Sync/` (compiled into both apps).
  - `SyncModels.swift`: what travels. `SyncMerge.swift`: the merge rules. `CloudSyncEngine.swift`: the only code that touches CloudKit (`CKSyncEngine`). `CloudRecordCoding.swift`: models to records and back.
- Each app has a thin adapter over its own storage: `MacSyncCoordinator.swift`, `SuperclipiOS/Sources/Sync/PhoneSync.swift`.
- Text, titles and snippet contents are stored in CloudKit **encrypted fields**, in the user's private database.
- Unpinned clips leave iCloud 30 days after last use (they stay on the devices that have them). Images over 10 MB sync as details only. Copied files do not sync.
