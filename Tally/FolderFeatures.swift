import SwiftUI
import UniformTypeIdentifiers

struct TallyFolder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var colorRaw: String = CounterColor.blue.rawValue
    var defaultCounterColorRaw: String = CounterColor.blue.rawValue
    var defaultSymbol: String = "timer"
    var defaultStepValues: [Int] = [1, 5, 10]
    var defaultResetReminder: ResetReminder = .none
    var defaultAutomaticReset: Bool = false
    var createdAt: Date = Date()

    var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension TallyStore {
    private static var foldersStorageKey: String { "tally.folders.v1" }

    var folders: [TallyFolder] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.foldersStorageKey),
                  let decoded = try? JSONDecoder().decode([TallyFolder].self, from: data) else { return [] }
            return decoded.sorted { $0.createdAt < $1.createdAt }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.foldersStorageKey)
            }
            objectWillChange.send()
        }
    }

    func ensureFoldersMigrated() {
        guard folders.isEmpty else { return }
        let names = Array(Set(counters.map(\.displayGroup))).filter { !$0.isEmpty }.sorted()
        folders = names.map { name in
            let sample = counters.first { $0.displayGroup == name }
            return TallyFolder(
                name: name,
                colorRaw: sample?.folderColorName ?? CounterColor.blue.rawValue,
                defaultCounterColorRaw: sample?.colorName ?? CounterColor.blue.rawValue,
                defaultSymbol: sample?.symbol ?? "number.square.fill",
                defaultStepValues: sample?.stepValues ?? [1, 5, 10],
                defaultResetReminder: sample?.resetReminder ?? .none,
                defaultAutomaticReset: sample?.automaticResetEnabled ?? false
            )
        }
    }

    func folder(named name: String) -> TallyFolder? {
        folders.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    @discardableResult
    func createFolder(_ folder: TallyFolder) -> Bool {
        let clean = folder.cleanName
        guard !clean.isEmpty, folder(named: clean) == nil else { return false }
        var copy = folder
        copy.name = clean
        var value = folders
        value.append(copy)
        folders = value
        return true
    }

    func updateFolder(_ folder: TallyFolder, previousName: String? = nil) {
        var value = folders
        guard let index = value.firstIndex(where: { $0.id == folder.id }) else { return }
        let oldName = previousName ?? value[index].name
        var updated = folder
        updated.name = folder.cleanName
        guard !updated.name.isEmpty else { return }
        value[index] = updated
        folders = value
        if oldName != updated.name {
            for counterIndex in counters.indices where counters[counterIndex].displayGroup == oldName {
                counters[counterIndex].group = updated.name
            }
        }
        updateFolderColor(group: updated.name, rawValue: updated.colorRaw)
    }

    func deleteFolder(_ folder: TallyFolder, keepCounters: Bool = true) {
        var value = folders
        value.removeAll { $0.id == folder.id }
        folders = value
        if keepCounters {
            for index in counters.indices where counters[index].displayGroup == folder.name {
                counters[index].group = ""
                counters[index].folderColorName = CounterColor.gray.rawValue
            }
        } else {
            let ids = counters.filter { $0.displayGroup == folder.name }.map(\.id)
            counters.removeAll { ids.contains($0.id) }
            history.removeAll { ids.contains($0.counterID) }
            sessions.removeAll { session in session.counterID.map(ids.contains) ?? false }
        }
    }

    func moveCounter(_ counter: TallyCounter, to folder: TallyFolder?) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        counters[index].group = folder?.name ?? ""
        counters[index].folderColorName = folder?.colorRaw ?? CounterColor.gray.rawValue
        counters[index].updatedAt = Date()
    }

    @discardableResult
    func quickCreateTimer(in folder: TallyFolder, name: String) -> TallyCounter? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let baseColor = CounterColor(rawValue: folder.defaultCounterColorRaw) ?? .blue
        guard let created = addCounter(
            name: clean,
            group: folder.name,
            goal: nil,
            symbol: folder.defaultSymbol,
            color: baseColor,
            notes: "",
            stepValues: folder.defaultStepValues,
            resetReminder: folder.defaultResetReminder
        ) else { return nil }
        if let index = counters.firstIndex(where: { $0.id == created.id }) {
            counters[index].colorName = folder.defaultCounterColorRaw
            counters[index].folderColorName = folder.colorRaw
            counters[index].automaticResetEnabled = folder.defaultAutomaticReset
        }
        startSession(counterID: created.id, title: clean, notes: "")
        return counters.first { $0.id == created.id }
    }
}

struct FolderEditorView: View {
    @EnvironmentObject private var store: TallyStore
    @Environment(\.dismiss) private var dismiss
    let existing: TallyFolder?

    @State private var name: String
    @State private var colorRaw: String
    @State private var counterColorRaw: String
    @State private var symbol: String
    @State private var steps: [Int]
    @State private var reset: ResetReminder
    @State private var automaticReset: Bool
    @State private var folderCustomColor = Color.blue
    @State private var counterCustomColor = Color.blue
    @State private var showingFolderCustomColor = false
    @State private var showingCounterCustomColor = false

    init(existing: TallyFolder? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _colorRaw = State(initialValue: existing?.colorRaw ?? CounterColor.blue.rawValue)
        _counterColorRaw = State(initialValue: existing?.defaultCounterColorRaw ?? CounterColor.blue.rawValue)
        _symbol = State(initialValue: existing?.defaultSymbol ?? "timer")
        _steps = State(initialValue: existing?.defaultStepValues ?? [1, 5, 10])
        _reset = State(initialValue: existing?.defaultResetReminder ?? .none)
        _automaticReset = State(initialValue: existing?.defaultAutomaticReset ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editorCard("Folder") {
                        TextField("Folder name", text: $name)
                            .font(.title3.weight(.semibold))
                    }

                    editorCard("Appearance") {
                        StoredColorMenu(title: "Folder Color", systemImage: "folder.fill", rawValue: $colorRaw, customColor: $folderCustomColor, showingCustomPicker: $showingFolderCustomColor)
                        Divider()
                        StoredColorMenu(title: "Counter Color", systemImage: "circle.fill", rawValue: $counterColorRaw, customColor: $counterCustomColor, showingCustomPicker: $showingCounterCustomColor)
                        Divider()
                        Menu {
                            ForEach(CounterSymbolOption.all) { option in
                                Button { symbol = option.symbol } label: {
                                    Label(option.title, systemImage: option.symbol)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Default Symbol").foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: symbol).foregroundStyle(TallyStoredColor.color(counterColorRaw))
                                Text(CounterSymbolOption.title(for: symbol)).foregroundStyle(.secondary)
                            }
                        }
                    }

                    editorCard("Quick Timer Presets") {
                        HStack {
                            Text("Step Buttons")
                            Spacer()
                            Text(steps.map(String.init).joined(separator: ", ")).foregroundStyle(.secondary)
                        }
                        Divider()
                        Picker("Reset Schedule", selection: $reset) {
                            ForEach(ResetReminder.allCases) { item in Text(item.title).tag(item) }
                        }
                        Divider()
                        Toggle("Reset Automatically", isOn: $automaticReset).disabled(reset == .none)
                        Text("The small timer button beside this folder uses these presets and starts a linked session immediately.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(existing == nil ? "New Folder" : "Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingFolderCustomColor) {
                CustomStoredColorSheet(title: "Folder Color", rawValue: $colorRaw, color: $folderCustomColor)
            }
            .sheet(isPresented: $showingCounterCustomColor) {
                CustomStoredColorSheet(title: "Default Counter Color", rawValue: $counterColorRaw, color: $counterCustomColor)
            }
        }
    }

    private func editorCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            content()
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func save() {
        var folder = existing ?? TallyFolder(name: name)
        let previousName = folder.name
        folder.name = name
        folder.colorRaw = colorRaw
        folder.defaultCounterColorRaw = counterColorRaw
        folder.defaultSymbol = symbol
        folder.defaultStepValues = TallyCounter.sanitizedStepValues(steps)
        folder.defaultResetReminder = reset
        folder.defaultAutomaticReset = automaticReset && reset != .none
        if existing == nil { _ = store.createFolder(folder) }
        else { store.updateFolder(folder, previousName: previousName) }
        dismiss()
    }
}

struct QuickFolderTimerSheet: View {
    @EnvironmentObject private var store: TallyStore
    @Environment(\.dismiss) private var dismiss
    let folder: TallyFolder
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 54)).foregroundStyle(TallyStoredColor.color(folder.colorRaw))
                TextField("Timer name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                Text("Creates a counter in \(folder.name) using the folder presets and starts its session.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(24)
            .navigationTitle("Quick Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        _ = store.quickCreateTimer(in: folder, name: name)
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
