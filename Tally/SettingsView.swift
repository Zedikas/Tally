import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var exportURL: URL?
    @State private var showingChangelog = false
    @State private var iconMessage: String?
    @State private var showingImporter = false
    @State private var replaceOnImport = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $store.theme) {
                        ForEach(TallyTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                }

                Section("App Icons") {
                    ForEach(TallyIcon.allCases) { icon in
                        Button { setIcon(icon) } label: {
                            HStack {
                                Image(systemName: icon.systemImage)
                                    .foregroundStyle(icon.tint)
                                    .frame(width: 32)
                                VStack(alignment: .leading) {
                                    Text(icon.title).font(.headline)
                                    Text(icon.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if UIApplication.shared.alternateIconName == icon.iconName || (UIApplication.shared.alternateIconName == nil && icon.iconName == nil) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    if let iconMessage {
                        Text(iconMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Backup & Import") {
                    Button("Create JSON Backup") { exportURL = store.exportJSONURL() }
                    Button("Export History CSV") { exportURL = store.exportCSVURL() }
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share Latest Export", systemImage: "square.and.arrow.up")
                        }
                    }

                    Divider()

                    Button {
                        replaceOnImport = false
                        showingImporter = true
                    } label: {
                        Label("Import & Merge JSON Backup", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        replaceOnImport = true
                        showingImporter = true
                    } label: {
                        Label("Replace With JSON Backup", systemImage: "arrow.triangle.2.circlepath")
                    }

                    if let importMessage {
                        Text(importMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.1 build 2")
                    Button("Changelog") { showingChangelog = true }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingChangelog) { ChangelogView() }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                handleImport(result)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importMessage = "No backup file selected."
                return
            }
            do {
                try store.importBackup(from: url, replaceExisting: replaceOnImport)
                importMessage = replaceOnImport ? "Backup imported and replaced current data." : "Backup imported and merged."
            } catch {
                importMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func setIcon(_ icon: TallyIcon) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconMessage = "This device or install method does not support alternate app icons."
            return
        }
        UIApplication.shared.setAlternateIconName(icon.iconName) { error in
            if let error {
                iconMessage = error.localizedDescription
            } else {
                iconMessage = "Icon changed to \(icon.title)."
            }
        }
    }
}

struct TallyIcon: Identifiable, CaseIterable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String?
    let systemImage: String
    let tint: Color

    static let allCases: [TallyIcon] = [
        TallyIcon(id: "primary", title: "Classic Blue", subtitle: "Default polished counter", iconName: nil, systemImage: "number.circle.fill", tint: .blue),
        TallyIcon(id: "neon", title: "Neon Dark", subtitle: "OLED-friendly electric blue", iconName: "NeonDark", systemImage: "sparkles", tint: .blue),
        TallyIcon(id: "glass", title: "Glass", subtitle: "Soft frosted blue", iconName: "Glass", systemImage: "circle.dashed", tint: .cyan),
        TallyIcon(id: "pearl", title: "Pearl", subtitle: "Bright and minimal", iconName: "Pearl", systemImage: "circle.fill", tint: .gray),
        TallyIcon(id: "amber", title: "Amber", subtitle: "Warm golden counter", iconName: "Amber", systemImage: "sun.max.fill", tint: .orange),
        TallyIcon(id: "green", title: "Tech Green", subtitle: "Neon productivity", iconName: "TechGreen", systemImage: "bolt.fill", tint: .green),
        TallyIcon(id: "purple", title: "Cosmic Purple", subtitle: "Deep violet glow", iconName: "CosmicPurple", systemImage: "moon.stars.fill", tint: .purple),
        TallyIcon(id: "synth", title: "Synthwave", subtitle: "Pink, purple, cyan", iconName: "Synthwave", systemImage: "waveform.path", tint: .pink)
    ]
}

struct ChangelogView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tally v1.1")
                            .font(.title2.weight(.heavy))
                        Text("A focused usability update for finding counters faster, creating counters from templates, organizing existing counters, and restoring backups.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("v1.1") {
                    ChangelogRow(title: "Search", detail: "Search counters by name, group, or notes directly from the Counters tab.")
                    ChangelogRow(title: "Sorting", detail: "Sort counters manually, by recent update, by name, or by value.")
                    ChangelogRow(title: "Templates", detail: "Create new counters from presets like Daily Goal, Water, Workout Reps, Inventory, Game Score, Reading, Streak, and Shopping.")
                    ChangelogRow(title: "Counter Actions", detail: "Duplicate counters and move them up or down from the card menu.")
                    ChangelogRow(title: "Backup Import", detail: "Import a JSON backup by merging it into your current counters or replacing all local data.")
                }

                Section("v1.0") {
                    ChangelogRow(title: "Multiple Counters", detail: "Create counters with names, groups, goals, notes, symbols, and colors.")
                    ChangelogRow(title: "Fast Counting", detail: "Use -1, +1, +5, +10, +100, reset, and undo.")
                    ChangelogRow(title: "Groups", detail: "Counters are automatically grouped into clean sections.")
                    ChangelogRow(title: "History", detail: "Every change is logged with before/after values and timestamps.")
                    ChangelogRow(title: "Backup & Export", detail: "Export a JSON backup or CSV history file with ShareLink.")
                    ChangelogRow(title: "Appearance", detail: "System, light, dark, and OLED black themes are included.")
                    ChangelogRow(title: "Alternate Icons", detail: "Includes the full interchangeable icon family inspired by the Universal Downloader icon setup.")
                }
            }
            .navigationTitle("Changelog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct ChangelogRow: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}
