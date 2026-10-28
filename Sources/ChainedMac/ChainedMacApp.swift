import AppKit
import SwiftUI

@MainActor
private final class ChainedMacApplicationDelegate: NSObject, NSApplicationDelegate {
    static weak var manager: WindowStripManager?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let manager = Self.manager else { return .terminateNow }
        guard manager.restore() else {
            let alert = NSAlert()
            alert.messageText = "ChainedMac couldn't restore every window"
            alert.informativeText = "\(manager.message)\n\nChainedMac will stay open so you can retry Restore."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Last-chance restoration for normal system-driven termination paths.
        _ = Self.manager?.restore()
    }
}

private enum MenuBarMark {
    static var image: NSImage? {
        guard let url = Bundle.main.url(forResource: "ChainedMacMenuBarMark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        // Use the mark's alpha as a mask so the menu-bar glyph stays white.
        image.size = NSSize(width: 12, height: 16)
        image.isTemplate = true
        return image
    }
}

@main
struct ChainedMacApp: App {
    @NSApplicationDelegateAdaptor(ChainedMacApplicationDelegate.self) private var appDelegate
    @StateObject private var manager: WindowStripManager

    init() {
        let manager = WindowStripManager()
        _manager = StateObject(wrappedValue: manager)
        ChainedMacApplicationDelegate.manager = manager
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(manager: manager)
        } label: {
            if let image = MenuBarMark.image {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .frame(width: 12, height: 16)
                    .accessibilityLabel("ChainedMac")
            } else {
                Image(systemName: "rectangle.split.3x1")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
