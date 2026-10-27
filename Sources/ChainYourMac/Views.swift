import AppKit
import SwiftUI

private enum Palette {
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let ink = Color(red: 0.12, green: 0.15, blue: 0.13)
    static let muted = Color(red: 0.43, green: 0.47, blue: 0.43)
    static let orange = Color(red: 0.91, green: 0.34, blue: 0.18)
    static let line = Color(red: 0.85, green: 0.85, blue: 0.81)
    static let green = Color(red: 0.77, green: 0.85, blue: 0.68)
}

struct MenuBarPanel: View {
    @ObservedObject var manager: WindowStripManager
    @AppStorage("chainYourMac.quickStartComplete") private var quickStartComplete = false

    var body: some View {
        Group {
            if manager.showingSettings { settingsPanel }
            else { mainPanel }
        }
        .padding(16)
        .frame(width: 320)
        .background(Palette.paper)
        .onAppear { manager.refresh() }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAIN YOUR MAC")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                    Text(manager.isArranged ? "\(manager.windows.count) windows in strip" : "Your workspace, in a line")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Circle().fill(manager.hasAccessibilityAccess ? Palette.green : Palette.orange.opacity(0.7))
                    .frame(width: 8, height: 8)
            }

            Rectangle().fill(Palette.line).frame(height: 1)

            if !quickStartComplete {
                QuickStartCard {
                    quickStartComplete = true
                }
            }

            if !manager.hasAccessibilityAccess {
                Text("Allow Accessibility so ChainYourMac can find, move, and resize app windows.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Button("Grant access") { manager.requestAccessibilityAccess() }
                    .buttonStyle(OrangeButtonStyle())
            } else {
                Button(manager.isArranged ? "Rearrange open windows" : "Arrange open windows") { manager.arrange() }
                    .buttonStyle(OrangeButtonStyle())
                HStack(spacing: 8) {
                    SmallAction(title: "Previous", symbol: "arrow.left", shortcut: "⇧←") { manager.focusPrevious() }
                    SmallAction(title: "Next", symbol: "arrow.right", shortcut: "⇧→") { manager.focusNext() }
                }
                HStack(spacing: 8) {
                    SmallAction(title: "Widen", symbol: "arrow.left.and.right", shortcut: "") { manager.widenFocusedWindow() }
                    SmallAction(title: "Center", symbol: "viewfinder", shortcut: "") { manager.centerFocusedWindow() }
                }
                if manager.isArranged {
                    Button("Restore original positions") { manager.restore() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 1)
                }
            }

            Text(manager.message)
                .font(.system(size: 10))
                .foregroundStyle(Palette.muted)
                .lineLimit(3)

            HStack {
                Text(manager.isArranged ? "\(manager.focusedIndex + 1) / \(manager.windows.count) · \(manager.focusedWindowTitle)" : "⇧← / →  Focus windows")
                    .font(.system(size: 9, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                Button("Settings…") { manager.showingSettings = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                QuitButton { manager.quit() }
            }
            .foregroundStyle(Palette.muted)
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Button { manager.showingSettings = false } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("SETTINGS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
            }

            Rectangle().fill(Palette.line).frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("ACCESSIBILITY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Palette.muted)
                Text(manager.hasAccessibilityAccess
                    ? "Accessibility access is on. ChainYourMac can move app windows."
                    : "Allow Accessibility so ChainYourMac can find and move app windows.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !manager.hasAccessibilityAccess {
                    Button("Grant access") { manager.requestAccessibilityAccess() }
                        .buttonStyle(OrangeButtonStyle())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("STRIP GAP")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Text("\(Int(manager.gap)) pt")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                Slider(value: $manager.gap, in: 0...80, step: 4)
                    .tint(Palette.orange)
                    .onChange(of: manager.gap) { _ in manager.reflow() }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("GLOBAL SHORTCUTS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Palette.muted)
                ShortcutRow(title: "Focus previous", shortcut: "⇧←")
                ShortcutRow(title: "Focus next", shortcut: "⇧→")
                ShortcutRow(title: "Restore positions", shortcut: "⌃⌥R")
                Text(manager.shortcutStatus)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("GETTING STARTED")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Palette.muted)
                Button("Show quick start") {
                    quickStartComplete = false
                    manager.showingSettings = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
            }

            HStack {
                Text("VERSION 1.0 · macOS 13+")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                Spacer()
                QuitButton { manager.quit() }
            }
        }
        .foregroundStyle(Palette.ink)
    }
}

private struct QuickStartCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("QUICK START")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
            }
            QuickStartStep(number: "1", title: "Allow Accessibility", detail: "Needed so macOS can move app windows.")
            QuickStartStep(number: "2", title: "Arrange open windows", detail: "ChainYourMac lays them out in one strip.")
            QuickStartStep(number: "3", title: "Move and restore", detail: "Use ⇧← / ⇧→ to focus; ⌃⌥R or Restore to return them.")
        }
        .foregroundStyle(Palette.ink)
        .padding(11)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct QuickStartStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.orange)
                .frame(width: 14, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 10, weight: .semibold))
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct QuitButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Quit", systemImage: "power")
        }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .medium))
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title).font(.system(size: 10))
            Spacer()
            Text(shortcut)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
    }
}

private struct SmallAction: View {
    let title: String
    let symbol: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .medium))
                Spacer(minLength: 1)
                if !shortcut.isEmpty { Text(shortcut).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted) }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity)
    }
}

private struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Palette.orange.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}

