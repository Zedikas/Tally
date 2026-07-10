import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var exportURL: URL?
    @State private var showingChangelog = false
    @State private var showingImporter = false
    @State private var importMessage: String?
    @State private var importPreview: TallyBackupPreview?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsNavigationRow(title: "Appearance", systemImage: "paintbrush.fill", color: .pink)
                    }
                    NavigationLink {
                        AppIconSettingsView()
                    } label: {
                        SettingsNavigationRow(title: "App Icon", systemImage: "app.badge.fill", color: .pink)
                    }
                }

                Section("Counter Management") {
                    NavigationLink {
                        ArchivedCountersView()
                    } label: {
                        LabeledContent("Archived Counters", value: "\(store.archivedCounters.count)")
                    }
                    LabeledContent("Pinned Counters", value: "\(store.activeCounters.filter(\.isPinned).count)")
                    LabeledContent("Locked Counters", value: "\(store.activeCounters.filter(\.isLocked).count)")
                    Text("Pin important counters, lock long-term totals, and restore archived counters here.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Backup & Import") {
                    Button("Create JSON Backup") { exportURL = store.exportJSONURL() }
                    Button("Export History CSV") { exportURL = store.exportCSVURL() }
                    Button("Export Sessions CSV") { exportURL = store.exportSessionsCSVURL() }
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Share Latest Export", systemImage: "square.and.arrow.up") }
                    }
                    Button { showingImporter = true } label: {
                        Label("Preview & Import JSON Backup", systemImage: "doc.text.magnifyingglass")
                    }
                    if let importMessage { Text(importMessage).font(.caption).foregroundStyle(.secondary) }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.6 build 8")
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
                    } catch { importMessage = "Import failed: \(error.localizedDescription)" }
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: handleImport)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { importMessage = "No backup file selected."; return }
            do {
                let securityScoped = url.startAccessingSecurityScopedResource()
                defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("Tally_Import_\(UUID().uuidString).json")
                try data.write(to: localURL, options: .atomic)
                importPreview = try store.previewBackup(from: localURL)
                importMessage = nil
            } catch { importMessage = "Preview failed: \(error.localizedDescription)" }
        case .failure(let error): importMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

struct SettingsNavigationRow: View {
    let title: String
    let systemImage: String
    let color: Color
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage).font(.title2).foregroundStyle(color).frame(width: 38)
            Text(title).font(.title3)
        }.padding(.vertical, 8)
    }
}

struct ArchivedCountersView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var searchText = ""

    private var counters: [TallyCounter] {
        guard !searchText.isEmpty else { return store.archivedCounters }
        return store.archivedCounters.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.displayGroup.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if counters.isEmpty {
                ContentUnavailableView("Archive Empty", systemImage: "archivebox", description: Text("Archived counters will appear here."))
            } else {
                ForEach(counters) { ArchivedCounterRow(counter: $0) }
            }
        }
        .navigationTitle("Archive")
        .searchable(text: $searchText, prompt: "Search archive")
    }
}

struct ArchivedCounterRow: View {
    @EnvironmentObject private var store: TallyStore
    let counter: TallyCounter
    @State private var showingDeleteConfirmation = false
    private var color: CounterColor { CounterColor(rawValue: counter.colorName) ?? .gray }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: counter.symbol).foregroundStyle(color.color).frame(width: 34, height: 34)
                .background(color.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(counter.name).font(.headline)
                Text("\(counter.displayGroup) • value \(counter.value)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Restore", systemImage: "arrow.uturn.backward") { store.restoreCounter(counter) }
                Button("Delete Forever", systemImage: "trash", role: .destructive) { showingDeleteConfirmation = true }
            } label: { Image(systemName: "ellipsis.circle").font(.title3) }
        }
        .confirmationDialog("Delete \(counter.name) forever?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Forever", role: .destructive) { store.permanentlyDeleteCounter(counter) }
        } message: { Text("This also removes its history and sessions and cannot be undone.") }
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
                    Text("Review this backup before choosing whether to merge it into Tally or replace current data.")
                        .font(.subheadline).foregroundStyle(.secondary)
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
                    Button { onImport(false); dismiss() } label: { Label("Merge Into Current Data", systemImage: "plus.square.on.square") }
                    Button(role: .destructive) { onImport(true); dismiss() } label: { Label("Replace Current Data", systemImage: "arrow.triangle.2.circlepath") }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
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
        .init(id: "primary", title: "Classic Blue", subtitle: "Tally", iconName: nil, systemImage: "number.circle.fill", tint: .blue),
        .init(id: "neon", title: "Neon Dark", subtitle: "Tally", iconName: "NeonDark", systemImage: "sparkles", tint: .blue),
        .init(id: "glass", title: "Glass", subtitle: "Tally", iconName: "Glass", systemImage: "circle.dashed", tint: .cyan),
        .init(id: "pearl", title: "Pearl", subtitle: "Tally", iconName: "Pearl", systemImage: "circle.fill", tint: .gray),
        .init(id: "amber", title: "Amber", subtitle: "Tally", iconName: "Amber", systemImage: "sun.max.fill", tint: .orange),
        .init(id: "green", title: "Tech Green", subtitle: "Tally", iconName: "TechGreen", systemImage: "bolt.fill", tint: .green),
        .init(id: "purple", title: "Cosmic Purple", subtitle: "Tally", iconName: "CosmicPurple", systemImage: "moon.stars.fill", tint: .purple),
        .init(id: "synth", title: "Synthwave", subtitle: "Tally", iconName: "Synthwave", systemImage: "waveform.path", tint: .pink)
    ]
}

struct ChangelogView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tally v1.6").font(.title2.weight(.heavy))
                        Text("A major single-target upgrade focused on deeper counter management, analytics, folders, and appearance customization.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Section("v1.6") {
                    ChangelogRow(title: "Counter Details", detail: "Tap a counter card to open its dashboard with quick actions, analytics, chart, notes, milestones, and recent history.")
                    ChangelogRow(title: "Pinned Favorites", detail: "Pin important counters into a dedicated Favorites section above folders.")
                    ChangelogRow(title: "Folder Styling", detail: "Folders show totals, counter counts, custom colors, and retain collapsible state.")
                    ChangelogRow(title: "Smart Resets", detail: "Optionally reset counters automatically when a new day, week, or month begins.")
                    ChangelogRow(title: "Milestones", detail: "Configure milestone values and record celebratory history events when reached.")
                    ChangelogRow(title: "Counter Locking", detail: "Lock counters to prevent accidental value changes and resets.")
                    ChangelogRow(title: "Advanced Analytics", detail: "Counter detail pages include change totals, net activity, best day, milestones, and 30-day charts.")
                    ChangelogRow(title: "Appearance Redesign", detail: "Appearance and App Icon now have dedicated Settings pages inspired by the supplied reference design.")
                    ChangelogRow(title: "Stable Color Selection", detail: "Counter and folder colors use full navigation pages instead of displaced popovers.")
                }
                Section("Earlier Releases") {
                    ChangelogRow(title: "v1.5.1", detail: "True-color selectors and Backup & Import layout fixes.")
                    ChangelogRow(title: "v1.5", detail: "Exact value entry, collapsible folders, readable symbols, and accent colors.")
                    ChangelogRow(title: "v1.4", detail: "Timed sessions and reset reminder metadata.")
                }
            }
            .navigationTitle("Changelog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct ChangelogRow: View {
    let title: String; let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 3)
    }
}
