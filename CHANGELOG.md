# Changelog

## 1.0.0

First shareable release of the native Mac and Windows apps.

- Added a universal macOS app and a self-contained Windows x64 app.
- Added first-run quick start, settings, persistent strip spacing, shortcut registration status, and Quit controls.
- Standardized global focus navigation on `Shift+Left` and `Shift+Right` for both platforms.
- Added restore shortcuts, repeatable release builds, GitHub release packages, and checksums.
- Updated the landing page to distinguish its browser simulator from real desktop window management.

### Known limits

- Windows was cross-compiled from macOS; running and accessibility behavior still need a Windows-machine check.
- The Mac release is ad hoc signed and the Windows executable is unsigned; store-distribution signing and notarization are not configured.
- Native window stacking, tabs, and automatic detection of newly opened windows are outside the v1 scope.
