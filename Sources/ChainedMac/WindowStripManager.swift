import AppKit
import ApplicationServices
import Combine
import SwiftUI

struct ManagedWindow: Identifiable {
    let id: String
    var title: String
    var appName: String
    var element: AXUIElement
    var frame: CGRect
    var originalFrame: CGRect
}

private struct AXFrameUpdate {
    var positionWritten = false
    var sizeWritten = false
    var issue: String?

    var succeeded: Bool { issue == nil }
}

@MainActor
final class WindowStripManager: ObservableObject {
    @Published private(set) var windows: [ManagedWindow] = []
    @Published private(set) var focusedIndex = 0
    @Published private(set) var hasAccessibilityAccess = AXIsProcessTrusted()
    @Published private(set) var message = "Arrange your open windows into one horizontal strip."
    @Published private(set) var isArranged = false
    @Published private(set) var shortcutStatus = "Checking global shortcuts…"
    @Published var gap: CGFloat
    @Published var showingSettings = false
    @Published var showingQuickStart = false

    private var baseX: CGFloat = 0
    private var accessibilityMonitor: AnyCancellable?
    private var windowDiscoveryIssue: String?
    private var lastFrameIssue: String?
    private let widthSteps: [CGFloat] = [0.56, 0.68, 0.80, 0.92]
    private var widthStepIndex = 1
    private let gapPreferenceKey = "chainedMac.stripGap"
    private let legacyGapPreferenceKey = "chainYourMac.stripGap"
    private lazy var globalHotKeys = GlobalHotKeys { [weak self] identifier in
        Task { @MainActor [weak self] in
            self?.handleGlobalShortcut(identifier)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: gapPreferenceKey) == nil,
           let legacyGap = UserDefaults(suiteName: "com.chainyourmac.app")?
                .object(forKey: legacyGapPreferenceKey) {
            defaults.set(legacyGap, forKey: gapPreferenceKey)
        }
        gap = CGFloat(defaults.object(forKey: gapPreferenceKey) as? Double ?? 28)
        _ = globalHotKeys
        updateShortcutStatus()
        accessibilityMonitor = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let isTrusted = AXIsProcessTrusted()
                guard isTrusted != self.hasAccessibilityAccess else { return }
                self.hasAccessibilityAccess = isTrusted
                if isTrusted {
                    self.message = "Accessibility enabled. Checking open windows…"
                    self.refresh()
                } else {
                    self.message = "Accessibility was turned off. Re-enable it to move or restore windows."
                }
            }
    }

    var focusedWindowTitle: String {
        guard windows.indices.contains(focusedIndex) else { return "No window selected" }
        return windows[focusedIndex].title
    }

    func refresh() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        guard hasAccessibilityAccess else {
            // Keep the original frames while a strip is arranged so they can
            // still be restored if access is granted again.
            if !isArranged { windows = [] }
            message = isArranged
                ? "Accessibility access is off. Re-enable it to continue or restore this strip."
                : "Accessibility access lets ChainedMac find, move, and resize app windows."
            return
        }

        let found = discoverWindows()
        guard isArranged else {
            windows = found
            focusedIndex = min(focusedIndex, max(0, windows.count - 1))
            message = windows.isEmpty
                ? (windowDiscoveryIssue ?? "No movable app windows are open yet. Open a regular app window and try again.")
                : "Ready to arrange \(windows.count) windows."
            return
        }

        let existingByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        let foundIDs = Set(found.map(\.id))
        var reconciled = found.map { candidate in
            guard var existing = existingByID[candidate.id] else { return candidate }
            existing.title = candidate.title
            existing.appName = candidate.appName
            existing.element = candidate.element
            existing.frame = candidate.frame
            return existing
        }
        // Keep tracked windows that are currently minimized or temporarily
        // unavailable. Dropping them here would discard their original frames
        // and make Restore (including the quit safeguard) impossible.
        reconciled.append(contentsOf: windows.filter {
            !foundIDs.contains($0.id) && !isInvalidAccessibilityElement($0.element)
        })
        windows = reconciled.sorted {
            if $0.frame.minX == $1.frame.minX { return $0.appName < $1.appName }
            return $0.frame.minX < $1.frame.minX
        }

        if windows.isEmpty {
            isArranged = false
            focusedIndex = 0
            message = "The arranged windows were closed."
            return
        }

        focusedIndex = min(focusedIndex, windows.count - 1)
        _ = reposition()
    }

    func requestAccessibilityAccess() {
        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
        if !hasAccessibilityAccess {
            message = "Enable ChainedMac in System Settings → Privacy & Security → Accessibility. It will reconnect automatically."
        }
    }

    func arrange() {
        guard hasAccessibilityAccess else {
            requestAccessibilityAccess()
            return
        }
        refresh()
        guard !windows.isEmpty else { return }

        windows = windows.map { window in
            var copy = window
            copy.originalFrame = window.frame
            return copy
        }
        baseX = windows[focusedIndex].frame.origin.x
        isArranged = true
        let positioned = reposition()
        raiseFocusedWindow()

        if positioned == windows.count {
            message = "\(windows.count) windows are in your strip."
        } else {
            message = lastFrameIssue ?? "Positioned \(positioned) of \(windows.count) windows. Some apps do not allow window positioning."
        }
    }

    func focusNext() {
        guard !windows.isEmpty else { refresh(); return }
        if !isArranged { arrange(); return }
        guard focusedIndex + 1 < windows.count else {
            message = "You’re at the last window in the strip."
            return
        }
        focusedIndex += 1
        let positioned = reposition()
        raiseFocusedWindow()
        message = positioned == windows.count
            ? "Focused \(windows[focusedIndex].title)."
            : (lastFrameIssue ?? "Focused the window, but macOS blocked part of the strip movement.")
    }

    func focusPrevious() {
        guard !windows.isEmpty else { refresh(); return }
        if !isArranged { arrange(); return }
        guard focusedIndex > 0 else {
            message = "You’re at the first window in the strip."
            return
        }
        focusedIndex -= 1
        let positioned = reposition()
        raiseFocusedWindow()
        message = positioned == windows.count
            ? "Focused \(windows[focusedIndex].title)."
            : (lastFrameIssue ?? "Focused the window, but macOS blocked part of the strip movement.")
    }

    func focus(_ id: String) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        if !isArranged { arrange() }
        focusedIndex = min(index, windows.count - 1)
        let positioned = reposition()
        raiseFocusedWindow()
        message = positioned == windows.count
            ? "Focused \(windows[focusedIndex].title)."
            : (lastFrameIssue ?? "Focused the window, but macOS blocked part of the strip movement.")
    }

    func widenFocusedWindow() {
        guard isArranged, windows.indices.contains(focusedIndex) else {
            message = "Arrange the strip before changing a window’s width."
            return
        }
        let nextWidthStepIndex = (widthStepIndex + 1) % widthSteps.count
        let screenWidth = screen(for: windows[focusedIndex])?.visibleFrame.width ?? 1280
        let requestedWidth = screenWidth * widthSteps[nextWidthStepIndex]
        let result = updateFrame(at: focusedIndex, { $0.size.width = requestedWidth })
        guard result.succeeded else {
            message = result.issue ?? "This app does not allow its window to be resized."
            return
        }
        widthStepIndex = nextWidthStepIndex
        _ = reposition()
        message = "Focused window width: \(Int(widthSteps[widthStepIndex] * 100))% of the display."
    }

    func centerFocusedWindow() {
        guard isArranged, windows.indices.contains(focusedIndex) else {
            message = "Arrange the strip before centering a window."
            return
        }
        let visibleFrame = screen(for: windows[focusedIndex])?.visibleFrame ?? CGRect(x: baseX, y: 0, width: 1280, height: 800)
        let targetX = visibleFrame.midX - windows[focusedIndex].frame.width / 2
        baseX += targetX - windows[focusedIndex].frame.origin.x
        let positioned = reposition()
        message = positioned == windows.count
            ? "Centered \(windows[focusedIndex].title)."
            : (lastFrameIssue ?? "macOS blocked part of the window movement.")
    }

    func reflow() {
        UserDefaults.standard.set(Double(gap), forKey: gapPreferenceKey)
        guard isArranged else { return }
        _ = reposition()
    }

    @discardableResult
    func restore() -> Bool {
        guard isArranged else {
            return true
        }

        hasAccessibilityAccess = AXIsProcessTrusted()
        guard hasAccessibilityAccess else {
            message = "Enable Accessibility for ChainedMac before restoring window positions."
            return false
        }

        var total = 0
        let originalFrames = windows.map(\.originalFrame)
        var restored = 0
        var issues: [String] = []
        for index in windows.indices {
            // A window closed while the strip was active no longer needs a
            // frame restore. Keep transient AX failures as failures so Quit
            // can be cancelled and the user can retry.
            if isInvalidAccessibilityElement(windows[index].element) { continue }
            total += 1
            let result = updateFrame(at: index) { $0 = originalFrames[index] }
            if result.succeeded { restored += 1 }
            else if let issue = result.issue { issues.append("\(windows[index].appName): \(issue)") }
        }

        guard restored == total else {
            message = issues.first ?? "Restored \(restored) of \(total) windows. Some apps refused the change."
            return false
        }

        isArranged = false
        focusedIndex = 0
        refresh()
        message = "Restored the original window positions."
        return true
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func handleGlobalShortcut(_ identifier: UInt32) {
        guard hasAccessibilityAccess else {
            message = "Grant Accessibility access in Settings before using global shortcuts."
            return
        }
        if windows.isEmpty { refresh() }
        guard !windows.isEmpty else {
            message = "Open app windows first, then try the shortcut again."
            return
        }

        switch identifier {
        case 1: focusPrevious()
        case 2: focusNext()
        case 3: restore()
        default: break
        }
    }

    private func updateShortcutStatus() {
        shortcutStatus = "\(globalHotKeys.registeredIdentifiers.count) of 3 global shortcuts registered."
    }

    @discardableResult
    private func reposition() -> Int {
        guard windows.indices.contains(focusedIndex) else { return 0 }
        let offsets = windows.indices.map { index in
            windows[..<index].reduce(CGFloat.zero) { $0 + $1.frame.width + gap }
        }
        let focusOffset = offsets[focusedIndex]
        var positioned = 0
        var issues: [String] = []

        for index in windows.indices {
            let x = baseX + offsets[index] - focusOffset
            let result = updateFrame(at: index) { $0.origin.x = x }
            if result.succeeded {
                positioned += 1
            } else if let issue = result.issue {
                issues.append("\(windows[index].appName): \(issue)")
            }
        }
        lastFrameIssue = issues.first
        return positioned
    }

    private func raiseFocusedWindow() {
        guard windows.indices.contains(focusedIndex) else { return }
        _ = AXUIElementPerformAction(windows[focusedIndex].element, kAXRaiseAction as CFString)
    }

    private func screen(for window: ManagedWindow) -> NSScreen? {
        let centerX = window.frame.midX
        let screens = NSScreen.screens.filter { $0.frame.minX <= centerX && centerX <= $0.frame.maxX }
        if let mainScreen = NSScreen.main, screens.contains(where: { $0 === mainScreen }) { return mainScreen }
        return screens.first ?? NSScreen.main
    }

    @discardableResult
    private func updateFrame(at index: Int, _ update: (inout CGRect) -> Void) -> AXFrameUpdate {
        guard windows.indices.contains(index) else {
            return AXFrameUpdate(issue: "That window is no longer available.")
        }
        let originalFrame = windows[index].frame
        var frame = windows[index].frame
        update(&frame)
        let result = writeFrame(windows[index].element, from: originalFrame, to: frame)
        if result.positionWritten { windows[index].frame.origin = frame.origin }
        if result.sizeWritten { windows[index].frame.size = frame.size }
        lastFrameIssue = result.issue
        return result
    }

    private func writeFrame(_ element: AXUIElement, from originalFrame: CGRect, to frame: CGRect) -> AXFrameUpdate {
        var result = AXFrameUpdate()
        if originalFrame.origin != frame.origin {
            var positionSettable = DarwinBoolean(false)
            let settableStatus = AXUIElementIsAttributeSettable(
                element,
                kAXPositionAttribute as CFString,
                &positionSettable
            )
            guard settableStatus == .success else {
                result.issue = accessibilityIssue(for: settableStatus, action: "move")
                return result
            }
            guard positionSettable.boolValue else {
                result.issue = "This app does not allow its window to move."
                return result
            }
            var point = frame.origin
            guard let value = AXValueCreate(.cgPoint, &point) else {
                result.issue = "Could not prepare the window position update."
                return result
            }
            let status = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
            guard status == .success else {
                result.issue = accessibilityIssue(for: status, action: "move")
                return result
            }
            result.positionWritten = true
        }

        if originalFrame.size != frame.size {
            var sizeSettable = DarwinBoolean(false)
            let settableStatus = AXUIElementIsAttributeSettable(
                element,
                kAXSizeAttribute as CFString,
                &sizeSettable
            )
            guard settableStatus == .success else {
                result.issue = accessibilityIssue(for: settableStatus, action: "resize")
                return result
            }
            guard sizeSettable.boolValue else {
                result.issue = "This app does not allow its window to be resized."
                return result
            }
            var size = frame.size
            guard let value = AXValueCreate(.cgSize, &size) else {
                result.issue = "Could not prepare the window size update."
                return result
            }
            let status = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
            guard status == .success else {
                result.issue = accessibilityIssue(for: status, action: "resize")
                return result
            }
            result.sizeWritten = true
        }
        return result
    }

    private func accessibilityIssue(for error: AXError, action: String) -> String {
        if error == .apiDisabled {
            return "macOS denied Accessibility access. Toggle ChainedMac off and on in System Settings, then reopen it."
        }
        if error == .cannotComplete {
            return "macOS did not complete the request to \(action) this window. Try again when the app is responsive."
        }
        return "macOS could not \(action) this window (Accessibility error: \(error))."
    }

    private func discoverWindows() -> [ManagedWindow] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result: [ManagedWindow] = []
        var unreadableApps = 0
        var accessDenied = false

        for app in NSWorkspace.shared.runningApplications where
            app.activationPolicy == .regular && app.processIdentifier != ownPID && !app.isTerminated {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsValue: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
            guard status == .success, let elements = windowsValue as? [AXUIElement] else {
                if status == .apiDisabled { accessDenied = true }
                else { unreadableApps += 1 }
                continue
            }

            for (index, element) in elements.enumerated() {
                if isMinimized(element) { continue }
                guard let frame = readFrame(element), frame.width >= 160, frame.height >= 100 else { continue }
                let title = readString(element, attribute: kAXTitleAttribute as CFString)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let appName = app.localizedName ?? "App"
                let displayTitle = title.isEmpty ? appName : title
                let stableID = "\(app.processIdentifier)-\(index)-\(displayTitle)"
                result.append(ManagedWindow(
                    id: stableID,
                    title: displayTitle,
                    appName: appName,
                    element: element,
                    frame: frame,
                    originalFrame: frame
                ))
            }
        }
        if result.isEmpty, accessDenied {
            windowDiscoveryIssue = "macOS denied Accessibility requests. Toggle ChainedMac off and on in Settings, then reopen it."
        } else if result.isEmpty, unreadableApps > 0 {
            windowDiscoveryIssue = "Accessibility is on, but macOS could not read windows from open apps. Quit and reopen ChainedMac, then try again."
        } else {
            windowDiscoveryIssue = nil
        }
        return result.sorted {
            if $0.frame.minX == $1.frame.minX { return $0.appName < $1.appName }
            return $0.frame.minX < $1.frame.minX
        }
    }

    private func isMinimized(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private func readString(_ element: AXUIElement, attribute: CFString) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return "" }
        return value as? String ?? ""
    }

    private func isInvalidAccessibilityElement(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .invalidUIElement
    }

    private func readFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
}
