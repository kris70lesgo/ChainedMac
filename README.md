# ChainYourMac 1.0

ChainYourMac turns the app windows you already have open into one horizontal strip. Move the strip focus with a keyboard shortcut, change the focused window's width, and restore the original window positions when you're done.

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

The arrow shortcuts are global while ChainYourMac is running. The app shows how many shortcuts registered successfully; another app may already own one. The focus buttons in the app remain available if a shortcut is unavailable.

## Install the Mac app

1. Download `ChainYourMac-macOS-universal.zip` and extract it.
2. Move `ChainYourMac.app` to Applications and open it.
3. In **System Settings → Privacy & Security → Accessibility**, enable ChainYourMac. Reopen its menu-bar popover if macOS asks you to restart it.
4. Open the popover, arrange your windows, then use `Shift+←` and `Shift+→` to move through the strip.

The universal package runs on Apple silicon and Intel Macs with macOS 13 or later. The current package is ad hoc signed because this project has no Developer ID signing certificate or notarization credentials. macOS may require you to confirm the first launch in Privacy & Security. A Developer ID signed and notarized package is needed for a smoother install for people who do not build the app themselves.

Click **Quit** in the popover to restore arranged windows and exit.

## Install the Windows app

1. Download and extract `ChainYourMac-Windows-x64.zip`.
2. Run `ChainYourMac.exe`. The app opens its controls and adds an icon to the notification area near the clock.
3. Choose **Arrange open windows**. Focus windows with `Shift+←` and `Shift+→`.
4. Right-click the notification-area icon to open ChainYourMac or quit.

The package is self-contained and does not require a separate .NET install. It targets Windows 11 x64 and Windows 10 LTSC/Enterprise x64, the Windows versions supported by the .NET 10 desktop runtime used here. The executable is not code signed, so SmartScreen may ask you to confirm that you want to run it. Windows-specific runtime behavior still needs verification on a Windows machine.

## Build from source

### macOS

Requires Xcode command-line tools and Swift 5.9 or newer. On a Mac, this builds arm64 and x86_64 release binaries, combines them into one universal app, signs it ad hoc, and creates a ZIP for the landing page preview:

```sh
./scripts/build-app.sh
```

Outputs: `dist/ChainYourMac.app`, `dist/ChainYourMac-macOS-universal.zip`, and a local copy in `website/downloads/`.

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

Pushing a version tag such as `v1.0.0` runs the release workflow. macOS CI builds the universal app; Windows CI builds the self-contained x64 app. The workflow attaches both ZIPs and a SHA-256 checksum file to the GitHub Release. The current workflow does not sign the packages; the Mac app is ad hoc signed and Windows SmartScreen may warn about the unsigned executable.

## Implementation notes

- The Mac app uses SwiftUI, AppKit, Carbon global hotkeys, and the Accessibility API.
- The Windows app uses WPF for its controls, a notification-area icon, Win32 global hotkeys, and native window-positioning APIs.
- The implementation is informed by static observations of the ChainYourMac browser experience recorded in [`docs/rea-observations.md`](docs/rea-observations.md). No native app source or distributable binary was available to reuse; this desktop implementation is independent.
- The website demo is a browser-only model. Its additional sample interactions, such as stacking and tabs, are not included in the v1 desktop apps.
