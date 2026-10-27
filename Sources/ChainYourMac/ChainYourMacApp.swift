import AppKit
import SwiftUI

private enum MenuBarMark {
    static var image: NSImage? {
        guard let url = Bundle.main.url(forResource: "ChainYourMacMenuBarMark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }
}

@main
struct ChainYourMacApp: App {
    @StateObject private var manager = WindowStripManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(manager: manager)
        } label: {
            if let image = MenuBarMark.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 20)
            } else {
                Image(systemName: "rectangle.split.3x1")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
