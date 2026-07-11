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
                Section("Customization") {
                    NavigationLink { AppearanceSettingsView() } label: {
                        SettingsNavigationRow(title: "Appearance", subtitle: "Theme, accent presets, and custom color", systemImage: "paintbrush.fill")
                    }
                    NavigationLink { AppIconSettingsView() } label: {
                        SettingsNavigationRow(title: "App Icon", subtitle: "Choose from the complete Tally icon family", systemImage: "app.badge.fill")
                    }
                }
                Section("Counter Management") {
                    NavigationLink { ArchivedCountersView() } label: {
                        SettingsNavigationRow(title: "Archived Counters", subtitle: "Restore or permanently remove counters", systemImage: "archivebox.fill", value: "\(store.archivedCounters.count)")
                    }
                    LabeledContent("Pinned Counters", value: "\(store.activeCounters.filter(\.isPinned).count)")
                    LabeledContent("Locked Counters", value: "\(store.activeCounters.filter(\.isLocked).count)")
                }
                Section("Backup & Import") {
                    Button { exportURL = store.exportJSONURL() } label: { Label("Create JSON Backup", systemImage: "externaldrive.fill") }
                    Button { exportURL = store.exportCSVURL() } label: { Label("Export History CSV", systemImage: "clock.arrow.circlepath") }
                    Button { exportURL = store.exportSessionsCSVURL() } label: { Label("Export Sessions CSV", systemImage: "timer") }
                    if let exportURL { ShareLink(item: exportURL) { Label("Share Latest Export", systemImage: "square.and.arrow.up") } }
                    Button { showingImporter = true } label: { Label("Preview & Import JSON Backup", systemImage: "doc.text.magnifyingglass") }
                    if let importMessage { Text(importMessage).font(.caption).foregroundStyle(.secondary) }
                }
                Section("About") {
                    LabeledContent("Version", value: "1.6.1 build 9")
                    Button("Changelog") { showingChangelog = true }
                }
            }
            .tallyOLEDBackground()
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
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { handleImport($0) }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { importMessage = "No backup file selected."; return }
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let local = FileManager.default.temporaryDirectory.appendingPathComponent("Tally_Import_\(UUID().uuidString).json")
                try data.write(to: local, options: .atomic)
                importPreview = try store.previewBackup(from: local)
                importMessage = nil
            } catch { importMessage = "Preview failed: \(error.localizedDescription)" }
        case .failure(let error): importMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var value: String? = nil
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage).font(.title2).frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let value { Text(value).foregroundStyle(.secondary) }
        }.padding(.vertical, 5)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var store: TallyStore
    @AppStorage(StoredAccentColor.presetKey) private var accentRaw = TallyAccentColor.blue.rawValue
    @AppStorage(StoredAccentColor.customKey) private var customHex = "FF1883"
    @State private var customColor = Color.pink
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            if store.theme == .oled { Color.black.ignoresSafeArea() }
            else if store.theme == .dark { Color(red: 0.055, green: 0.055, blue: 0.065).ignoresSafeArea() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Appearance", selection: $store.theme) {
                        Text("Default").tag(TallyTheme.system)
                        Text("Light").tag(TallyTheme.light)
                        Text("Dark").tag(TallyTheme.dark)
                        Text("OLED").tag(TallyTheme.oled)
                    }
                    .pickerStyle(.segmented).padding(14)
                    .background(store.theme == .oled ? Color(white: 0.035) : Color.clear, in: RoundedRectangle(cornerRadius: 22))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))

                    Text("Accent Theme").font(.title2.weight(.heavy))
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(TallyAccentColor.allCases) { accent in
                            Button { accentRaw = accent.rawValue } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        Circle().fill(accent.color.opacity(0.25)).frame(width: 54, height: 54)
                                        Circle().fill(accent.color).frame(width: 34, height: 34)
                                        if accentRaw == accent.rawValue { Image(systemName: "checkmark").fontWeight(.black).foregroundStyle(.white) }
                                    }
                                    Text(accent.title).font(.subheadline.weight(.semibold)).foregroundStyle(accent.color)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(store.theme == .oled ? Color(white: 0.035) : Color.clear, in: RoundedRectangle(cornerRadius: 20))
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Custom Theme Color").font(.headline)
                                Text("Use any color instead of a preset.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ColorPicker("", selection: $customColor, supportsOpacity: false).labelsHidden()
                        }
                        HStack {
                            Circle().fill(customColor).frame(width: 34, height: 34)
                            Text("#\(customHex.uppercased())").font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("Use Custom") {
                                customHex = customColor.hexString()
                                accentRaw = StoredAccentColor.customValue
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(18)
                    .background(store.theme == .oled ? Color(white: 0.035) : Color.clear, in: RoundedRectangle(cornerRadius: 22))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                }.padding()
            }
        }
        .navigationTitle("Appearance")
        .onAppear { customColor = Color(hex: customHex) ?? .pink }
        .onChange(of: customColor) { _, value in customHex = value.hexString() }
    }
}

struct AppIconSettingsView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var iconMessage: String?

    var body: some View {
        List {
            Section("Tally Icon Family") {
                ForEach(TallyIcon.allCases) { icon in
                    Button { setIcon(icon) } label: {
                        HStack(spacing: 16) {
                            iconPreview(icon)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(icon.title).font(.headline).foregroundStyle(.primary)
                                Text(icon.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if icon.isSelected { Image(systemName: "checkmark").font(.title3.weight(.heavy)).foregroundStyle(icon.tint) }
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain)
                }
            }
            if let iconMessage { Section { Text(iconMessage).font(.caption).foregroundStyle(.secondary) } }
        }
        .tallyOLEDBackground()
        .navigationTitle("App Icon")
    }

    @ViewBuilder private func iconPreview(_ icon: TallyIcon) -> some View {
        #if canImport(UIKit)
        if let path = Bundle.main.path(forResource: icon.previewName, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable().scaledToFit().frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        } else if let image = UIImage(named: icon.previewName) {
            Image(uiImage: image).resizable().scaledToFit().frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(icon.tint.gradient).frame(width: 64, height: 64)
                .overlay(Image(systemName: "number").font(.title.bold()).foregroundStyle(.white))
        }
        #else
        RoundedRectangle(cornerRadius: 15).fill(icon.tint).frame(width: 64, height: 64)
        #endif
    }

    private func setIcon(_ icon: TallyIcon) {
        guard UIApplication.shared.supportsAlternateIcons else { iconMessage = "This install method does not support alternate icons."; return }
        UIApplication.shared.setAlternateIconName(icon.iconName) { error in
            iconMessage = error?.localizedDescription ?? "Icon changed to \(icon.title)."
        }
    }
}

struct ArchivedCountersView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var searchText = ""
    private var filtered: [TallyCounter] {
        searchText.isEmpty ? store.archivedCounters : store.archivedCounters.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.displayGroup.localizedCaseInsensitiveContains(searchText) }
    }
    var body: some View {
        List {
            if filtered.isEmpty { ContentUnavailableView("Archive Empty", systemImage: "archivebox", description: Text("Archived counters will appear here.")) }
            else { ForEach(filtered) { ArchivedCounterRow(counter: $0) } }
        }
        .tallyOLEDBackground()
        .navigationTitle("Archive").searchable(text: $searchText, prompt: "Search archive")
    }
}

struct ArchivedCounterRow: View {
    @EnvironmentObject private var store: TallyStore
    let counter: TallyCounter
    @State private var showingDelete = false
    private var color: Color { TallyStoredColor.color(counter.colorName, fallback: .gray) }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: counter.symbol).foregroundStyle(color).frame(width: 36, height: 36).background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading) { Text(counter.name).font(.headline); Text("\(counter.displayGroup) • value \(counter.value)").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Menu {
                Button("Restore", systemImage: "arrow.uturn.backward") { store.restoreCounter(counter) }
                Button("Delete Forever", systemImage: "trash", role: .destructive) { showingDelete = true }
            } label: { Image(systemName: "ellipsis.circle").font(.title3) }
        }
        .confirmationDialog("Delete \(counter.name) forever?", isPresented: $showingDelete) { Button("Delete Forever", role: .destructive) { store.permanentlyDeleteCounter(counter) } }
    }
}

struct BackupImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: TallyBackupPreview
    let onImport: (Bool) -> Void
    var body: some View {
        NavigationStack {
            List {
                Section("Backup Details") {
                    LabeledContent("Version", value: preview.version)
                    LabeledContent("Exported", value: preview.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Theme", value: preview.themeTitle)
                }
                Section("Contents") {
                    LabeledContent("Counters", value: "\(preview.counterCount)")
                    LabeledContent("Active", value: "\(preview.activeCounterCount)")
                    LabeledContent("Archived", value: "\(preview.archivedCounterCount)")
                    LabeledContent("History", value: "\(preview.historyCount)")
                    LabeledContent("Sessions", value: "\(preview.sessionCount)")
                }
                Section {
                    Button { onImport(false); dismiss() } label: { Label("Merge Into Current Data", systemImage: "plus.square.on.square") }
                    Button(role: .destructive) { onImport(true); dismiss() } label: { Label("Replace Current Data", systemImage: "arrow.triangle.2.circlepath") }
                }
            }
            .navigationTitle("Import Preview").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct TallyIcon: Identifiable, CaseIterable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String?
    let previewName: String
    let tint: Color
    var isSelected: Bool { UIApplication.shared.alternateIconName == iconName || (UIApplication.shared.alternateIconName == nil && iconName == nil) }
    static let allCases: [TallyIcon] = [
        .init(id: "primary", title: "Classic Blue", subtitle: "The original polished Tally counter", iconName: nil, previewName: "TallyIconClassicBlue", tint: .blue),
        .init(id: "neon", title: "Neon Dark", subtitle: "Electric blue for OLED screens", iconName: "NeonDark", previewName: "TallyIconNeonDark", tint: .blue),
        .init(id: "glass", title: "Glass", subtitle: "Soft frosted blue", iconName: "Glass", previewName: "TallyIconGlass", tint: .cyan),
        .init(id: "pearl", title: "Pearl", subtitle: "Bright and minimal", iconName: "Pearl", previewName: "TallyIconPearl", tint: .gray),
        .init(id: "amber", title: "Amber", subtitle: "Warm golden counter", iconName: "Amber", previewName: "TallyIconAmber", tint: .orange),
        .init(id: "green", title: "Tech Green", subtitle: "Neon productivity", iconName: "TechGreen", previewName: "TallyIconTechGreen", tint: .green),
        .init(id: "purple", title: "Cosmic Purple", subtitle: "Deep violet glow", iconName: "CosmicPurple", previewName: "TallyIconCosmicPurple", tint: .purple),
        .init(id: "synth", title: "Synthwave", subtitle: "Pink, purple, and cyan", iconName: "Synthwave", previewName: "TallyIconSynthwave", tint: .pink)
    ]
}

struct ChangelogView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tally v1.6.1").font(.title2.weight(.heavy))
                        Text("A focused usability update for faster creation, safer deletion, true OLED styling, and reliable icon previews.").foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Section("v1.6.1") {
                    ChangelogRow(title: "Compact Style Menus", detail: "Counter color, folder color, and symbol selection now stay inside the creation screen.")
                    ChangelogRow(title: "Custom Counter Colors", detail: "Choose any custom color for individual counters and folders.")
                    ChangelogRow(title: "Compact Action Menu", detail: "Shorter labels and grouped actions prevent the counter menu from becoming excessively tall.")
                    ChangelogRow(title: "Direct Delete", detail: "Permanently delete a counter directly from its action menu after confirmation.")
                    ChangelogRow(title: "True OLED Mode", detail: "OLED now uses pure black backgrounds and near-black surfaces, while regular Dark remains visibly lighter.")
                    ChangelogRow(title: "Icon Preview Repair", detail: "App icon previews now load directly from bundled PNG resources with a fallback preview.")
                }
                Section("v1.6") {
                    ChangelogRow(title: "Counter Detail Pages", detail: "Dedicated dashboards with quick actions, notes, milestones, sessions, recent history, averages, and charts.")
                    ChangelogRow(title: "Favorites and Folders", detail: "Pinned counters, folder colors, totals, smart resets, milestones, and locking.")
                }
            }
            .navigationTitle("Changelog").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct ChangelogRow: View {
    let title: String
    let detail: String
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical, 3) }
}
