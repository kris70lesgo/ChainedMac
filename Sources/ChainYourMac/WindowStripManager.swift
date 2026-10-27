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

    var succeeded: Bool { positionWritten || sizeWritten }
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

    private var baseX: CGFloat = 0
    private let widthSteps: [CGFloat] = [0.56, 0.68, 0.80, 0.92]
    private var widthStepIndex = 1
    private let gapPreferenceKey = "chainYourMac.stripGap"
    private lazy var globalHotKeys = GlobalHotKeys { [weak self] identifier in
        Task { @MainActor [weak self] in
            self?.handleGlobalShortcut(identifier)
        }
    }

    init() {
        gap = CGFloat(UserDefaults.standard.object(forKey: gapPreferenceKey) as? Double ?? 28)
        _ = globalHotKeys
        updateShortcutStatus()
    }

    var focusedWindowTitle: String {
        guard windows.indices.contains(focusedIndex) else { return "No window selected" }
        return windows[focusedIndex].title
    }

    func refresh() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        guard hasAccessibilityAccess else {
            windows = []
            isArranged = false
            message = "Accessibility access lets ChainYourMac move and resize app windows."
            return
        }

        let found = discoverWindows()
        guard isArranged else {
            windows = found
            focusedIndex = min(focusedIndex, max(0, windows.count - 1))
            message = windows.isEmpty ? "No movable app windows are open yet." : "Ready to arrange \(windows.count) windows."
            return
        }

        let existingByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        windows = found.map { candidate in
            guard var existing = existingByID[candidate.id] else { return candidate }
            existing.title = candidate.title
            existing.appName = candidate.appName
            existing.element = candidate.element
            existing.frame = candidate.frame
            return existing
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
            message = "Enable ChainYourMac in System Settings → Privacy & Security → Accessibility, then reopen this menu."
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
        let moved = reposition()
        raiseFocusedWindow()

        if moved == windows.count {
            message = "\(windows.count) windows are in your strip."
        } else {
            message = "Moved \(moved) of \(windows.count) windows. Some apps do not allow window positioning."
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
        _ = reposition()
        raiseFocusedWindow()
        message = "Focused \(windows[focusedIndex].title)."
    }

    func focusPrevious() {
        guard !windows.isEmpty else { refresh(); return }
        if !isArranged { arrange(); return }
        guard focusedIndex > 0 else {
            message = "You’re at the first window in the strip."
            return
        }
        focusedIndex -= 1
        _ = reposition()
        raiseFocusedWindow()
        message = "Focused \(windows[focusedIndex].title)."
    }

    func focus(_ id: String) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        if !isArranged { arrange() }
        focusedIndex = min(index, windows.count - 1)
        _ = reposition()
        raiseFocusedWindow()
        message = "Focused \(windows[focusedIndex].title)."
    }

    func widenFocusedWindow() {
        guard isArranged, windows.indices.contains(focusedIndex) else {
            message = "Arrange the strip before changing a window’s width."
            return
        }
        widthStepIndex = (widthStepIndex + 1) % widthSteps.count
        let screenWidth = screen(for: windows[focusedIndex])?.visibleFrame.width ?? 1280
        let requestedWidth = screenWidth * widthSteps[widthStepIndex]
        guard updateFrame(at: focusedIndex, { $0.size.width = requestedWidth }) else {
            message = "This app does not allow its window to be resized."
            return
        }
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
        _ = reposition()
        message = "Centered \(windows[focusedIndex].title)."
    }

    func reflow() {
        UserDefaults.standard.set(Double(gap), forKey: gapPreferenceKey)
        guard isArranged else { return }
        _ = reposition()
    }

    func restore() {
        guard isArranged else {
            message = "Arrange a strip first."
            return
        }

        let total = windows.count
        let restored = windows.reduce(into: 0) { count, window in
            if writeFrame(window.element, window.originalFrame).succeeded { count += 1 }
        }
        isArranged = false
        focusedIndex = 0
        refresh()
        message = restored == total
            ? "Restored the original window positions."
            : "Restored \(restored) of \(total) windows."
    }

    func quit() {
        if isArranged { restore() }
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
        var moved = 0

        for index in windows.indices {
            let x = baseX + offsets[index] - focusOffset
            if updateFrame(at: index, { $0.origin.x = x }) { moved += 1 }
        }
        return moved
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
    private func updateFrame(at index: Int, _ update: (inout CGRect) -> Void) -> Bool {
        guard windows.indices.contains(index) else { return false }
        var frame = windows[index].frame
        update(&frame)
        let result = writeFrame(windows[index].element, frame)
        if result.positionWritten { windows[index].frame.origin = frame.origin }
        if result.sizeWritten { windows[index].frame.size = frame.size }
        return result.succeeded
    }

    private func writeFrame(_ element: AXUIElement, _ frame: CGRect) -> AXFrameUpdate {
        var positionSettable = DarwinBoolean(false)
        var sizeSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &positionSettable)
        AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &sizeSettable)

        var result = AXFrameUpdate()
        if positionSettable.boolValue {
            var point = frame.origin
            if let value = AXValueCreate(.cgPoint, &point) {
                result.positionWritten = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
            }
        }
        if sizeSettable.boolValue {
            var size = frame.size
            if let value = AXValueCreate(.cgSize, &size) {
                result.sizeWritten = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) == .success
            }
        }
        return result
    }

    private func discoverWindows() -> [ManagedWindow] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result: [ManagedWindow] = []

        for app in NSWorkspace.shared.runningApplications where
            app.activationPolicy == .regular && app.processIdentifier != ownPID && !app.isTerminated {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let elements = windowsValue as? [AXUIElement] else { continue }

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
