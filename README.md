# ChainedMac 1.0

ChainedMac turns the app windows you already have open into one horizontal strip. Move the strip focus with a keyboard shortcut, change the focused window's width, and restore the original window positions when you're done.

The v1 desktop apps have the same core workflow on macOS and Windows. The landing page contains a separate browser simulator; its sample windows are illustrations and do not control desktop apps.

## What v1 includes

- Arrange visible, movable app windows in a horizontal strip.
- Focus the previous or next window with a global shortcut or the app controls.
- Widen the focused window, center it on its display, and adjust the gap between windows.
- Restore the positions captured when the strip was arranged.
- A first-run quick start, a settings panel, status for registered shortcuts, and an explicit Quit command.
- Local preferences only. No account, cloud service, or telemetry is included.

This first version does not stack app windows into tabs, move windows between virtual desktops, or continuously watch for newly opened windows. Open the app controls and arrange again after opening or closing windows. Windows that the operating system or the app itself will not allow to move may remain where they were.

## Shortcuts

| Action | macOS | Windows |
| --- | --- | --- |
| Focus previous window | `Shift+←` | `Shift+←` |
| Focus next window | `Shift+→` | `Shift+→` |
| Restore original positions | `Control+Option+R` | `Control+Alt+R` |

The arrow shortcuts are global while ChainedMac is running. The app shows how many shortcuts registered successfully; another app may already own one. The focus buttons in the app remain available if a shortcut is unavailable.

## Install the Mac app

1. Open `ChainedMac-macOS-universal.dmg`.
2. Drag `ChainedMac.app` onto the Applications shortcut in the DMG window, then eject the disk image.
3. Open ChainedMac from Applications.
4. In **System Settings → Privacy & Security → Accessibility**, enable ChainedMac. The menu-bar app rechecks this permission automatically; if macOS still blocks window access, turn the ChainedMac switch off and on, then reopen the app.
5. Open the popover, arrange your windows, then use `Shift+←` and `Shift+→` to move through the strip.

The universal package runs on Apple silicon and Intel Macs with macOS 13 or later. Local builds use the `ChainedMac Local Code Signing` identity in the login Keychain when it is available; otherwise they fall back to ad hoc signing. This self-signed identity keeps the app's code requirement stable across local builds, but Apple does not verify or notarize it, so macOS may still show a first-launch warning. GitHub Actions releases remain ad hoc signed until a signing identity is configured there.

Click **Quit** in the Mac popover or Windows controls to restore arranged windows and exit. ChainedMac stays open if it cannot restore every tracked window, so you can retry. A force quit or crash can bypass this normal shutdown cleanup.

## Install the Windows app

1. Download and extract `ChainedMac-Windows-x64.zip`.
2. Run `ChainedMac.exe`. The app opens its controls and adds an icon to the notification area near the clock.
3. Choose **Arrange open windows**. Focus windows with `Shift+←` and `Shift+→`.
4. Right-click the notification-area icon to open ChainedMac or quit.

The package is self-contained and does not require a separate .NET install. It targets Windows 11 x64 and Windows 10 LTSC/Enterprise x64, the Windows versions supported by the .NET 10 desktop runtime used here. The executable is not code signed, so SmartScreen may ask you to confirm that you want to run it. Windows-specific runtime behavior still needs verification on a Windows machine.

## Build from source

### macOS

Requires Xcode command-line tools and Swift 5.9 or newer. On a Mac, this builds arm64 and x86_64 release binaries, combines them into one universal app, signs with the local self-signed identity when present (or ad hoc otherwise), and creates a drag-to-Applications DMG:

```sh
./scripts/build-app.sh
```

Outputs: `dist/ChainedMac.app`, `dist/ChainedMac-macOS-universal.dmg`, and a local copy in `website/downloads/`.

### Windows

Requires the .NET 10 SDK. Run the PowerShell script on Windows:

```powershell
./scripts/build-windows.ps1
```

The same package can be cross-compiled from macOS with the .NET 10 SDK and Windows targeting packs available through NuGet:

```sh
./scripts/build-windows.sh
```

The app itself must run on Windows for runtime and UI verification.

### Landing page

Open `website/index.html` or serve the `website/` directory with any static HTTP server. The browser simulator is illustrative only; the native apps perform real window management.

## GitHub release builds

Pushing a version tag such as `v1.0.7` runs the release workflow. macOS CI builds the universal app; Windows CI builds the self-contained x64 app. The workflow attaches the Mac DMG, Windows ZIP, and a SHA-256 checksum file to the GitHub Release. The Mac app is ad hoc signed and Windows SmartScreen may warn about the unsigned executable.

## Implementation notes

- The Mac app uses SwiftUI, AppKit, Carbon global hotkeys, and the Accessibility API.
- The Windows app uses WPF for its controls, a notification-area icon, Win32 global hotkeys, and native window-positioning APIs.
- The implementation is informed by static observations of the original ChainYourMac browser experience recorded in [`docs/rea-observations.md`](docs/rea-observations.md). No native app source or distributable binary was available to reuse; this desktop implementation is independent.
- The website demo is a browser-only model. Its additional sample interactions, such as stacking and tabs, are not included in the v1 desktop apps.
