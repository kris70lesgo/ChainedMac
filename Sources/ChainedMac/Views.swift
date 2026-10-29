import AppKit
import SwiftUI

private enum Palette {
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let ink = Color(red: 0.12, green: 0.15, blue: 0.13)
    static let muted = Color(red: 0.43, green: 0.47, blue: 0.43)
    static let lavender = Color(red: 0.83, green: 0.77, blue: 0.94)
    static let lavenderInk = Color(red: 0.35, green: 0.24, blue: 0.52)
    static let line = Color(red: 0.86, green: 0.83, blue: 0.90)
    static let sliderTrack = Color(red: 0.72, green: 0.68, blue: 0.78)
    static let green = Color(red: 0.77, green: 0.85, blue: 0.68)
}

struct MenuBarPanel: View {
    @ObservedObject var manager: WindowStripManager

    var body: some View {
        Group {
            if manager.showingSettings { settingsPanel }
            else if manager.showingQuickStart { quickStartPanel }
            else { mainPanel }
        }
        .padding(16)
        .frame(width: 320)
        .background(Palette.paper)
        .onAppear {
            manager.refresh()
        }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.lavenderInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAINEDMAC")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                    Text(manager.isArranged ? "\(manager.windows.count) windows in strip" : "Your workspace, in a line")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Circle().fill(manager.hasAccessibilityAccess ? Palette.green : Palette.lavender)
                    .frame(width: 8, height: 8)
                Text(manager.hasAccessibilityAccess ? "ACCESS ON" : "ACCESS NEEDED")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(manager.hasAccessibilityAccess ? Palette.muted : Palette.lavenderInk)
            }

            Rectangle().fill(Palette.line).frame(height: 1)

            if !manager.hasAccessibilityAccess {
                Text("Allow Accessibility so ChainedMac can find, move, and resize app windows.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Button("Grant access") { manager.requestAccessibilityAccess() }
                    .buttonStyle(AccentButtonStyle())
            } else {
                Button(manager.isArranged ? "Rearrange open windows" : "Arrange open windows") { manager.arrange() }
                    .buttonStyle(AccentButtonStyle())
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
                Button { manager.showingQuickStart = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More")
                    .help("Quick start")
                Button { manager.showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                    .help("Settings")
                QuitButton { manager.quit() }
            }
            .foregroundStyle(Palette.muted)
        }
        .foregroundStyle(Palette.ink)
    }

    private var quickStartPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { manager.showingQuickStart = false } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("QUICK START")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
            }

            Rectangle().fill(Palette.line).frame(height: 1)

            QuickStartCard()
        }
        .foregroundStyle(Palette.ink)
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
                    ? "Accessibility access is on. ChainedMac can move app windows."
                    : "Allow Accessibility so ChainedMac can find and move app windows.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !manager.hasAccessibilityAccess {
                    Button("Grant access") { manager.requestAccessibilityAccess() }
                        .buttonStyle(AccentButtonStyle())
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
                HStack {
                    Spacer(minLength: 0)
                    StripGapSlider(value: $manager.gap)
                        .frame(width: 216, height: 28)
                    Spacer(minLength: 0)
                }
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

            HStack {
                Text("VERSION 1.0.8 · macOS 13+")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                Spacer()
                QuitButton { manager.quit() }
            }
        }
        .foregroundStyle(Palette.ink)
    }
}

private struct StripGapSlider: View {
    @Binding var value: CGFloat

    private let range: ClosedRange<CGFloat> = 0...80
    private let step: CGFloat = 4
    private let thumbDiameter: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let travel = max(geometry.size.width - thumbDiameter, 1)
            let fraction = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.sliderTrack)
                    .frame(width: travel, height: 7)
                    .offset(x: thumbDiameter / 2)

                Capsule()
                    .fill(Palette.lavenderInk)
                    .frame(width: travel * fraction, height: 7)
                    .offset(x: thumbDiameter / 2)

                Circle()
                    .fill(Palette.paper)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .overlay(Circle().stroke(Palette.lavenderInk, lineWidth: 2))
                    .shadow(color: Palette.ink.opacity(0.16), radius: 2, y: 1)
                    .offset(x: travel * fraction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                updateValue(at: gesture.location.x, width: geometry.size.width)
            })
            .accessibilityElement()
            .accessibilityLabel("Strip gap")
            .accessibilityValue("\(Int(value)) points")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(value + step, range.upperBound)
                case .decrement:
                    value = max(value - step, range.lowerBound)
                @unknown default:
                    break
                }
            }
        }
        .frame(height: 28)
    }

    private func updateValue(at location: CGFloat, width: CGFloat) {
        let travel = max(width - thumbDiameter, 1)
        let fraction = min(max((location - thumbDiameter / 2) / travel, 0), 1)
        let rawValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        let snappedValue = (rawValue / step).rounded() * step
        value = min(max(snappedValue, range.lowerBound), range.upperBound)
    }
}

private struct QuickStartCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            QuickStartStep(number: "1", title: "Allow Accessibility", detail: "Needed so macOS can move app windows.")
            QuickStartStep(number: "2", title: "Arrange open windows", detail: "ChainedMac lays them out in one strip.")
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
                .foregroundStyle(Palette.lavenderInk)
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
            Image(systemName: "power")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quit ChainedMac")
        .help("Quit ChainedMac")
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

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.lavenderInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Palette.lavender.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}

