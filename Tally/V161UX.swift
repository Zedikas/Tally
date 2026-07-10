import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum TallyStoredColor {
    static let customPrefix = "custom:"

    static func preset(_ raw: String) -> CounterColor? {
        CounterColor(rawValue: raw)
    }

    static func customHex(_ raw: String) -> String? {
        guard raw.hasPrefix(customPrefix) else { return nil }
        let hex = String(raw.dropFirst(customPrefix.count)).uppercased()
        return Color(hex: hex) == nil ? nil : hex
    }

    static func raw(customHex: String) -> String {
        customPrefix + normalizedHex(customHex)
    }

    static func normalizedHex(_ value: String) -> String {
        let clean = value.uppercased().filter { $0.isHexDigit }
        return clean.count == 6 ? clean : "0A84FF"
    }

    static func color(_ raw: String, fallback: CounterColor = .blue) -> Color {
        if let preset = preset(raw) { return preset.color }
        if let hex = customHex(raw), let color = Color(hex: hex) { return color }
        return fallback.color
    }

    static func title(_ raw: String, fallback: CounterColor = .blue) -> String {
        if let preset = preset(raw) { return preset.title }
        if let hex = customHex(raw) { return "#\(hex)" }
        return fallback.title
    }
}

struct StoredColorMenu: View {
    let title: String
    let systemImage: String
    @Binding var rawValue: String
    @Binding var customColor: Color
    @Binding var showingCustomPicker: Bool

    private var resolved: Color { TallyStoredColor.color(rawValue) }

    var body: some View {
        Menu {
            ForEach(CounterColor.allCases) { option in
                Button {
                    rawValue = option.rawValue
                } label: {
                    Label(option.title, systemImage: rawValue == option.rawValue ? "checkmark.circle.fill" : "circle.fill")
                }
            }
            Divider()
            Button {
                customColor = resolved
                showingCustomPicker = true
            } label: {
                Label("Custom Color…", systemImage: "paintpalette.fill")
            }
        } label: {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: systemImage).foregroundStyle(resolved)
                Text(TallyStoredColor.title(rawValue)).foregroundStyle(resolved)
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(resolved)
            }
        }
    }
}

struct CustomStoredColorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var rawValue: String
    @Binding var color: Color

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom Color") {
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                    HStack {
                        Circle().fill(color).frame(width: 30, height: 30)
                        Text("#\(color.hexString())").font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Color") {
                        rawValue = TallyStoredColor.raw(customHex: color.hexString())
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension TallyStore {
    func folderColorRaw(for group: String) -> String {
        activeCounters.first(where: { $0.displayGroup == group })?.folderColorName ?? CounterColor.gray.rawValue
    }

    func updateFolderColor(group: String, rawValue: String) {
        for index in counters.indices where counters[index].displayGroup == group {
            counters[index].folderColorName = rawValue
            counters[index].updatedAt = Date()
        }
    }
}

struct TallySurfaceModifier: ViewModifier {
    @EnvironmentObject private var store: TallyStore
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(store.theme == .oled ? .hidden : .automatic)
            .background(store.theme == .oled ? Color.black : Color.clear)
    }
}

extension View {
    func tallyOLEDBackground() -> some View { modifier(TallySurfaceModifier()) }
}
