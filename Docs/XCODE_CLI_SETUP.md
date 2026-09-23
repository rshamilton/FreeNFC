# Building NFC Forge from the command line

Xcode lives on the external drive, not `/Applications`, so `xcodebuild`/`xcrun` don't work
out of the box. This is the one-time-per-shell fix, plus the exact commands used to scaffold
and verify this project.

## 1. Point the toolchain at the external Xcode

Xcode 26.3 is at:

```
/Volumes/Applications/Applications/Xcode.app
```

Don't run `sudo xcode-select -s ...` for this (it needs a password and changes the setting
system-wide for every terminal). Instead, export `DEVELOPER_DIR` in the shell you're building
from — it overrides the active toolchain for just that shell/command:

```bash
export DEVELOPER_DIR=/Volumes/Applications/Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Add that `export` line to `~/.zshrc` if you want it to persist across terminal sessions.

## 2. Regenerating the Xcode project

This project's `.xcodeproj` is generated from `project.yml` using
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (installed via `brew install xcodegen`).
Whenever you add/remove/rename source files, regenerate the project so Xcode picks them up:

```bash
cd "/Users/Ryan/Downloads/Free NFC"
xcodegen generate
```

This is safe to run any time — it rebuilds `FreeNFC.xcodeproj` from `project.yml` and the
`FreeNFC/` source tree without touching your source files.

## 3. Building from the command line

**Compile-check (no signing, no device/simulator needed)** — useful for quickly verifying the
code compiles after a change:

```bash
export DEVELOPER_DIR=/Volumes/Applications/Applications/Xcode.app/Contents/Developer
cd "/Users/Ryan/Downloads/Free NFC"
xcodebuild -project FreeNFC.xcodeproj -target FreeNFC -sdk iphoneos \
  -configuration Debug CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

Note `-target` rather than `-scheme` — building the scheme makes `xcodebuild` resolve a
destination (device/simulator), which on a fresh Xcode install fails until platform support
files are downloaded (see below). Building the target directly skips that resolution and just
compiles.

**Building for the iOS Simulator** works the same way once a simulator runtime is installed
(see below):

```bash
xcodebuild -project FreeNFC.xcodeproj -target FreeNFC -sdk iphonesimulator \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Simulator note: **CoreNFC cannot run in the Simulator at all** — there is no NFC hardware to
emulate. A simulator build only proves the code compiles; you can't scan, read, or write a tag
until it's running on a real iPhone.

## 4. A fresh Xcode install needs its platform support downloaded once

The first time you build on a machine, `xcodebuild` and the asset-catalog compiler (`actool`)
need at least one iOS platform/simulator runtime registered, even for plain compiles. If you
see errors like:

```
error: iOS 26.2 is not installed. Please download and install the platform...
error: No available simulator runtimes for platform iphonesimulator. SimServiceContext supportedRuntimes=[]
```

run:

```bash
export DEVELOPER_DIR=/Volumes/Applications/Applications/Xcode.app/Contents/Developer
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
```

The platform download is large (~8.4GB) and can take a while — it only needs to happen once
per machine/Xcode install.

**If `actool` still reports `SimServiceContext supportedRuntimes=[]` after the download
finishes:** this happened during this project's own setup — `xcrun simctl list runtimes` kept
coming back empty right after the download, even though `xcrun simctl runtime list -j` showed
the runtime sitting in a `"Ready"` state. CoreSimulatorService just hadn't picked it up yet.
What fixed it here, in order of how much it helps:

```bash
# 1. Simplest: just run the download command again -- a second pass often finishes the
#    registration step that a first pass leaves half-done.
xcodebuild -downloadPlatform iOS
xcrun simctl list runtimes            # check again

# 2. If a duplicate/unusable image is stuck, clear it and restart the simulator service
xcrun simctl runtime list -j          # look for a second entry with "state":"Unusable"
xcrun simctl runtime delete <its-identifier>
killall -9 com.apple.CoreSimulator.CoreSimulatorService
xcrun simctl list runtimes
```

If neither works, opening Xcode.app itself once (`open -a
/Volumes/Applications/Applications/Xcode.app`) and letting its first-launch flow finish is the
most reliable fallback — its GUI setup is more thorough than the CLI-only path.

This was purely an environment quirk in `actool`/CoreSimulatorService, unrelated to the app's
source — the full Swift codebase (52 files) was verified to compile cleanly on its own before
this was resolved. Once the runtime is registered, `xcodebuild -project FreeNFC.xcodeproj
-target FreeNFC -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build` produces a
complete, ready-to-run `.app` (confirmed with `** BUILD SUCCEEDED **` including the asset
catalog and app icon).

## 5. Running on a real iPhone (required for actually testing NFC)

Command-line builds can compile and even install to a paired device, but the *first* run needs
Xcode's GUI once to pick your Apple ID as the signing Team (Signing & Capabilities tab). This
must be a paid Apple Developer Program team — free Personal Teams can't use the Near Field
Communication Tag Reading capability. The team ID lives in `project.yml` (`DEVELOPMENT_TEAM`),
so set it there too or `xcodegen generate` will put the old value back.

After that's set up once, you can build-and-install from the command line. List paired devices:

```bash
xcrun devicectl list devices
```

Then build/install to a specific device by its identifier:

```bash
xcodebuild -project FreeNFC.xcodeproj -scheme FreeNFC -configuration Debug \
  -destination "id=<DEVICE-IDENTIFIER>" -allowProvisioningUpdates build
```

Easiest path day-to-day: open `FreeNFC.xcodeproj` in Xcode, pick your iPhone from the device
menu, and hit Run (⌘R). NFC needs a physical device held near a tag — there's no way around
that for testing.

## 6. "Missing required entitlement" when the NFC capability is already added

CoreNFC reports `NFCReaderError` code 2 (`readerErrorSecurityViolation`, "Missing required
entitlement") for more than a missing capability. `NFCSessionManager` polls `.iso14443` and
`.iso18092` by default, and iOS refuses to start that session unless Info.plist also has:

- `com.apple.developer.nfc.readersession.iso7816.select-identifiers` — the ISO 7816 AIDs to
  select (we list the NFC Forum Type 4 NDEF apps `D2760000850101` / `D2760000850100`).
- `com.apple.developer.nfc.readersession.felica.systemcodes` — FeliCa system codes to poll
  (`12FC` NDEF, `88B4` Lite-S, `0003` transit, `FE00` common area). The `FFFF` wildcard isn't
  allowed.

An ISO 7816 or FeliCa tag that doesn't answer one of the listed AIDs / system codes won't be
detected, so add entries there if you need to talk to other cards.

Both keys, and the entitlement, are defined in `project.yml` — XcodeGen rewrites
`FreeNFC/App/Info.plist` and `FreeNFC.entitlements` from it on every `xcodegen generate`, so
edit `project.yml`, not just the generated files.

To confirm what actually got signed into a device build:

```bash
APP=~/Library/Developer/Xcode/DerivedData/FreeNFC-*/Build/Products/Debug-iphoneos/"Free NFC.app"
codesign -d --entitlements - $APP
plutil -p $APP/Info.plist | grep nfc
```

The entitlement only needs `TAG` — Apple no longer documents `NDEF`, and App Store Connect
rejects uploads that still include it.
