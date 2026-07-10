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
    @State private var importMessage: String?
    @State private var importPreview: TallyBackupPreview?

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

                Section("Counter Management") {
                    NavigationLink {
                        ArchivedCountersView()
                    } label: {
                        LabeledContent("Archived Counters", value: "\(store.archivedCounters.count)")
                    }
                    Text("Archiving replaces hard delete on the main counter screen. You can restore archived counters here or permanently delete them later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Backup & Import") {
                    Button("Create JSON Backup") { exportURL = store.exportJSONURL() }
                    Button("Export History CSV") { exportURL = store.exportCSVURL() }
                    Button("Export Sessions CSV") { exportURL = store.exportSessionsCSVURL() }
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share Latest Export", systemImage: "square.and.arrow.up")
                        }
                    }

                    Divider()

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Preview & Import JSON Backup", systemImage: "doc.text.magnifyingglass")
                    }

                    if let importMessage {
                        Text(importMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.4 build 5")
                    Button("Changelog") { showingChangelog = true }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingChangelog) { ChangelogView() }
            .sheet(item: $importPreview) { preview in
                BackupImportPreviewView(preview: preview) { replaceExisting in
                    do {
                        try store.importBackup(from: preview.url, replaceExisting: replaceExisting)
                        importMessage = replaceExisting ? "Backup imported and replaced current data." : "Backup imported and merged."
                        importPreview = nil
                    } catch {
                        importMessage = "Import failed: \(error.localizedDescription)"
                    }
                }
            }
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
                let localURL = try copyImportFileToTemporaryLocation(url)
                importPreview = try store.previewBackup(from: localURL)
                importMessage = nil
            } catch {
                importMessage = "Preview failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func copyImportFileToTemporaryLocation(_ url: URL) throws -> URL {
        let securityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("Tally_Import_\(UUID().uuidString).json")
        try data.write(to: localURL, options: .atomic)
        return localURL
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

struct ArchivedCountersView: View {
    @EnvironmentObject private var store: TallyStore

    var body: some View {
        List {
            if store.archivedCounters.isEmpty {
                ContentUnavailableView("Archive Empty", systemImage: "archivebox", description: Text("Archived counters will appear here."))
            } else {
                Section {
                    ForEach(store.archivedCounters) { counter in
                        ArchivedCounterRow(counter: counter)
                    }
                } footer: {
                    Text("Permanent delete also removes that counter's history and sessions. Restore keeps all values, history, and sessions.")
                }
            }
        }
        .navigationTitle("Archive")
    }
}

struct ArchivedCounterRow: View {
    @EnvironmentObject private var store: TallyStore
    let counter: TallyCounter
    @State private var showingDeleteConfirmation = false

    private var color: CounterColor {
        CounterColor(rawValue: counter.colorName) ?? .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: counter.symbol)
                .foregroundStyle(color.color)
                .frame(width: 34, height: 34)
                .background(color.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(counter.name)
                    .font(.headline)
                Text("\(counter.displayGroup) • value \(counter.value)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Restore") { store.restoreCounter(counter) }
                Button("Delete Forever", role: .destructive) { showingDeleteConfirmation = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
        }
        .confirmationDialog("Delete \(counter.name) forever?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Forever", role: .destructive) { store.permanentlyDeleteCounter(counter) }
        } message: {
            Text("This also removes its history and sessions and cannot be undone.")
        }
    }
}

struct BackupImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: TallyBackupPreview
    let onImport: (Bool) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backup Preview")
                            .font(.title2.weight(.heavy))
                        Text("Review this backup before choosing whether to merge it into Tally or replace current data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Backup Details") {
                    LabeledContent("Version", value: preview.version)
                    LabeledContent("Exported", value: preview.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Theme", value: preview.themeTitle)
                }

                Section("Contents") {
                    LabeledContent("Counters", value: "\(preview.counterCount)")
                    LabeledContent("Active", value: "\(preview.activeCounterCount)")
                    LabeledContent("Archived", value: "\(preview.archivedCounterCount)")
                    LabeledContent("History Entries", value: "\(preview.historyCount)")
                    LabeledContent("Sessions", value: "\(preview.sessionCount)")
                }

                Section {
                    Button {
                        onImport(false)
                        dismiss()
                    } label: {
                        Label("Merge Into Current Data", systemImage: "plus.square.on.square")
                    }

                    Button(role: .destructive) {
                        onImport(true)
                        dismiss()
                    } label: {
                        Label("Replace Current Data", systemImage: "arrow.triangle.2.circlepath")
                    }
                } footer: {
                    Text("Merge creates new counter IDs to avoid collisions. Replace overwrites counters, history, sessions, theme, and archive state.")
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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
                        Text("Tally v1.4")
                            .font(.title2.weight(.heavy))
                        Text("A sessions update with timed counting blocks, session exports, and lightweight reset reminder notes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("v1.4") {
                    ChangelogRow(title: "Sessions Tab", detail: "Start timed counting sessions linked to a counter or as standalone sessions.")
                    ChangelogRow(title: "Session Summaries", detail: "Ending a session records duration, start value, end value, and delta.")
                    ChangelogRow(title: "Counter Session Actions", detail: "Start or end a linked session directly from a counter card menu.")
                    ChangelogRow(title: "Session Export", detail: "Export sessions as CSV from Settings.")
                    ChangelogRow(title: "Reset Reminder Notes", detail: "Counters can now carry daily, weekly, or monthly reset reminder metadata without notification extensions.")
                    ChangelogRow(title: "Backup Sessions", detail: "JSON backups now include sessions and import previews show session counts.")
                }

                Section("v1.3") {
                    ChangelogRow(title: "Archive Instead of Delete", detail: "The main counter screen now archives counters instead of permanently deleting them.")
                    ChangelogRow(title: "Archive Manager", detail: "Restore archived counters or permanently delete them from Settings.")
                    ChangelogRow(title: "Custom Step Buttons", detail: "Each counter can now define its own three positive step buttons.")
                    ChangelogRow(title: "Import Preview", detail: "Backup imports now show version, export date, counter counts, archive counts, and history count before merge or replace.")
                    ChangelogRow(title: "Safer Data Migration", detail: "Older backups load with default archive and step settings so existing data is preserved.")
                }

                Section("v1.2") {
                    ChangelogRow(title: "Stats Tab", detail: "Adds a dedicated dashboard with selected ranges for Today, 7 days, 30 days, and all time.")
                    ChangelogRow(title: "Daily / Weekly Summaries", detail: "Shows changes, net movement, active counters, goal completion, and day-by-day activity.")
                    ChangelogRow(title: "Streak Insights", detail: "Detects consecutive days with positive activity for counters based on history.")
                    ChangelogRow(title: "Top Counters", detail: "Ranks counters by activity and net change for the selected stats range.")
                    ChangelogRow(title: "History Filters", detail: "Filter history by Today, Last 7 Days, Positive, Negative, and Resets.")
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