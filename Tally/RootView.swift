import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TallyStore
    @AppStorage(StoredAccentColor.presetKey) private var accentColorRaw = TallyAccentColor.blue.rawValue
    @AppStorage(StoredAccentColor.customKey) private var customAccentHex = "FF1883"

    var body: some View {
        TabView {
            CountersView().tabItem { Label("Counters", systemImage: "number.circle.fill") }
            SessionsView().tabItem { Label("Sessions", systemImage: "timer") }
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
            HistoryView().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(StoredAccentColor.resolve(accentColorRaw, customHex: customAccentHex))
        .background { if store.theme == .oled { Color.black.ignoresSafeArea() } }
        .task {
            store.ensureFoldersMigrated()
            store.performAutomaticResets()
        }
    }
}

struct CountersView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var showingAddCounter = false
    @State private var showingAddFolder = false
    @State private var editingFolder: TallyFolder?
    @State private var quickTimerFolder: TallyFolder?
    @State private var searchText = ""
    @State private var sort: CounterSort = .manual
    @State private var exactValueCounter: TallyCounter?
    @AppStorage("tally.collapsedFolders.v17") private var collapsedFoldersRaw = ""

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        quickStats
                        if !pinnedCounters.isEmpty { favoritesSection }

                        ForEach(visibleFolders) { folder in
                            folderSection(folder)
                        }

                        if !unfiledCounters.isEmpty || store.folders.isEmpty {
                            unfiledSection
                        }

                        if visibleCounters.isEmpty && store.folders.isEmpty {
                            ContentUnavailableView(
                                searchText.isEmpty ? "No Counters or Folders" : "No Matches",
                                systemImage: "square.grid.2x2",
                                description: Text(searchText.isEmpty ? "Create a folder or a counter to begin." : "Try another search.")
                            )
                            .padding(.top, 36)
                        }
                    }
                    .safeAreaPadding(.top, 8)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Tally")
            .searchable(text: $searchText, prompt: "Search counters and folders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { store.undoLastAction() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .disabled(store.history.isEmpty)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(CounterSort.allCases) { option in
                                Label(option.title, systemImage: option.systemImage).tag(option)
                            }
                        }
                        Divider()
                        Button("Expand All", systemImage: "rectangle.expand.vertical") { collapsedFoldersRaw = "" }
                        Button("Collapse All", systemImage: "rectangle.compress.vertical") {
                            collapsedFoldersRaw = store.folders.map(\.id.uuidString).joined(separator: "\n")
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down.circle") }

                    Menu {
                        Button("New Counter", systemImage: "number.square.fill") { showingAddCounter = true }
                        Button("New Folder", systemImage: "folder.badge.plus") { showingAddFolder = true }
                    } label: { Label("Create", systemImage: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showingAddCounter) { CounterEditorView(mode: .add) }
            .sheet(isPresented: $showingAddFolder) { FolderEditorView() }
            .sheet(item: $editingFolder) { FolderEditorView(existing: $0) }
            .sheet(item: $quickTimerFolder) { QuickFolderTimerSheet(folder: $0) }
            .sheet(item: $exactValueCounter) { ExactValueEditor(counter: $0) }
            .task { store.ensureFoldersMigrated() }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Favorites", systemImage: "pin.fill")
                .font(.headline.weight(.heavy)).padding(.horizontal)
            ForEach(pinnedCounters) { counter in
                draggableCard(counter)
            }
        }
    }

    private func folderSection(_ folder: TallyFolder) -> some View {
        let items = counters(in: folder)
        let tint = TallyStoredColor.color(folder.colorRaw, fallback: .blue)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { toggleFolder(folder) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isCollapsed(folder) ? "folder.fill" : "folder.fill.badge.minus")
                            .foregroundStyle(tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name).font(.headline.weight(.heavy)).foregroundStyle(tint)
                            Text("\(items.count) counters • Total \(items.map(\.value).reduce(0, +))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button { quickTimerFolder = folder } label: {
                    Image(systemName: "timer.circle.fill")
                        .font(.title2).foregroundStyle(tint)
                }
                .accessibilityLabel("Quick timer in \(folder.name)")

                Menu {
                    Button("Edit Folder", systemImage: "pencil") { editingFolder = folder }
                    Button("Quick Timer", systemImage: "timer") { quickTimerFolder = folder }
                    Divider()
                    Button("Delete Folder", systemImage: "trash", role: .destructive) {
                        store.deleteFolder(folder, keepCounters: true)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }

                Image(systemName: isCollapsed(folder) ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if !isCollapsed(folder) {
                ForEach(items.filter { !$0.isPinned }) { counter in draggableCard(counter) }
                if items.isEmpty {
                    Text("Drop a counter here or use the timer button.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 4)
        .background(tint.opacity(0.035), in: RoundedRectangle(cornerRadius: 24))
        .dropDestination(for: String.self) { values, _ in
            guard let raw = values.first, let id = UUID(uuidString: raw),
                  let counter = store.counters.first(where: { $0.id == id }) else { return false }
            store.moveCounter(counter, to: folder)
            return true
        }
        .animation(.snappy, value: isCollapsed(folder))
    }

    private var unfiledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Unfiled", systemImage: "tray")
                    .font(.headline.weight(.heavy)).foregroundStyle(.secondary)
                Spacer()
                Text("Drop here to remove from a folder")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            ForEach(unfiledCounters.filter { !$0.isPinned }) { counter in draggableCard(counter) }

            if unfiledCounters.isEmpty {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.secondary.opacity(0.05))
                    .frame(height: 58)
                    .overlay(Text("Drop counters here").font(.caption).foregroundStyle(.secondary))
                    .padding(.horizontal)
            }
        }
        .dropDestination(for: String.self) { values, _ in
            guard let raw = values.first, let id = UUID(uuidString: raw),
                  let counter = store.counters.first(where: { $0.id == id }) else { return false }
            store.moveCounter(counter, to: nil)
            return true
        }
    }

    private func draggableCard(_ counter: TallyCounter) -> some View {
        CounterCard(counter: counter) { exactValueCounter = counter }
            .padding(.horizontal)
            .draggable(counter.id.uuidString) {
                HStack(spacing: 8) {
                    Image(systemName: counter.symbol)
                    Text(counter.name).fontWeight(.semibold)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
    }

    private var collapsedFolders: Set<String> {
        Set(collapsedFoldersRaw.split(separator: "\n").map(String.init))
    }
    private func isCollapsed(_ folder: TallyFolder) -> Bool { collapsedFolders.contains(folder.id.uuidString) }
    private func toggleFolder(_ folder: TallyFolder) {
        var values = collapsedFolders
        if values.contains(folder.id.uuidString) { values.remove(folder.id.uuidString) }
        else { values.insert(folder.id.uuidString) }
        collapsedFoldersRaw = values.sorted().joined(separator: "\n")
    }

    private var visibleCounters: [TallyCounter] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty ? store.activeCounters : store.activeCounters.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.displayGroup.localizedCaseInsensitiveContains(trimmed) ||
            $0.notes.localizedCaseInsensitiveContains(trimmed)
        }
        switch sort {
        case .manual: return filtered
        case .recent: return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .name: return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .value: return filtered.sorted { $0.value > $1.value }
        }
    }

    private var visibleFolders: [TallyFolder] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return store.folders }
        return store.folders.filter { folder in
            folder.name.localizedCaseInsensitiveContains(trimmed) || visibleCounters.contains { $0.displayGroup == folder.name }
        }
    }
    private var knownFolderNames: Set<String> { Set(store.folders.map { $0.name.lowercased() }) }
    private var unfiledCounters: [TallyCounter] {
        visibleCounters.filter { counter in
            let raw = counter.group.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty || !knownFolderNames.contains(raw.lowercased())
        }
    }
    private var pinnedCounters: [TallyCounter] { visibleCounters.filter(\.isPinned) }
    private func counters(in folder: TallyFolder) -> [TallyCounter] {
        visibleCounters.filter { $0.displayGroup.localizedCaseInsensitiveCompare(folder.name) == .orderedSame }
    }

    private var background: some View {
        Group {
            if store.theme == .oled { Color.black.ignoresSafeArea() }
            else if store.theme == .dark { Color(red: 0.055, green: 0.055, blue: 0.065).ignoresSafeArea() }
            else {
                LinearGradient(colors: [Color(.systemBackground), Color.blue.opacity(0.06)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
        }
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            StatPill(title: "Active", value: "\(store.activeCounters.count)", systemImage: "number")
            StatPill(title: "Folders", value: "\(store.folders.count)", systemImage: "folder")
            StatPill(title: "Total", value: "\(visibleCounters.map(\.value).reduce(0, +))", systemImage: "sum")
        }
        .padding(.horizontal)
    }
}

struct StatPill: View {
    @EnvironmentObject private var store: TallyStore
    let title: String
    let value: String
    let systemImage: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.black)).contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(store.theme == .oled ? Color(white: 0.035) : Color.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CounterCard: View {
    @EnvironmentObject private var store: TallyStore
    let counter: TallyCounter
    let onEditExactValue: () -> Void
    @State private var showingEdit = false
    @State private var showingResetConfirmation = false
    @State private var showingArchiveConfirmation = false
    @State private var showingDeleteConfirmation = false

    private var color: Color { TallyStoredColor.color(counter.colorName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                NavigationLink {
                    CounterDetailView(counterID: counter.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: counter.symbol)
                            .font(.title2.weight(.bold)).foregroundStyle(color)
                            .frame(width: 44, height: 44)
                            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Text(counter.name).font(.headline.weight(.heavy)).foregroundStyle(.primary)
                                if counter.isPinned { Image(systemName: "pin.fill").font(.caption) }
                                if counter.isLocked { Image(systemName: "lock.fill").font(.caption) }
                            }
                            if let goal = counter.goal, goal > 0 {
                                Text("Goal: \(counter.value) / \(goal)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            } else if !counter.notes.isEmpty {
                                Text(counter.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            if counter.resetReminder != .none {
                                Label(counter.automaticResetEnabled ? "Auto \(counter.resetReminder.title)" : counter.resetReminder.title, systemImage: counter.resetReminder.systemImage)
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.buttonStyle(.plain)
                Spacer()
                Button(action: onEditExactValue) {
                    Text("\(counter.value)").font(.system(size: 42, weight: .black, design: .rounded)).foregroundStyle(color).monospacedDigit()
                }.buttonStyle(.plain).disabled(counter.isLocked)
            }
            if let progress = counter.progress { ProgressView(value: progress).tint(color) }
            HStack(spacing: 8) {
                StepButton(title: "−1", isDisabled: counter.isLocked) { store.safeAdjust(counter, by: -1) }
                ForEach(counter.stepValues, id: \.self) { step in
                    StepButton(title: "+\(step)", isDisabled: counter.isLocked) { store.safeAdjust(counter, by: step) }
                }
                Menu {
                    Button(counter.isPinned ? "Unpin" : "Pin", systemImage: counter.isPinned ? "pin.slash" : "pin") { store.togglePinned(counter) }
                    Button(counter.isLocked ? "Unlock" : "Lock", systemImage: counter.isLocked ? "lock.open" : "lock") { store.toggleLocked(counter) }
                    Button("Exact Value", systemImage: "number.square") { onEditExactValue() }.disabled(counter.isLocked)
                    if let session = store.activeSession(for: counter) {
                        Button("End Session", systemImage: "stop.circle") { store.endSession(session) }
                    } else {
                        Button("Start Session", systemImage: "timer") { store.startSession(counterID: counter.id, title: counter.name, notes: "") }
                    }
                    Divider()
                    Button("Edit", systemImage: "pencil") { showingEdit = true }
                    Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicateCounter(counter) }
                    Menu("Reorder", systemImage: "arrow.up.arrow.down") {
                        Button("Move Up", systemImage: "arrow.up") { store.moveCounter(counter, by: -1) }
                        Button("Move Down", systemImage: "arrow.down") { store.moveCounter(counter, by: 1) }
                    }
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("+100", systemImage: "plus.circle") { store.safeAdjust(counter, by: 100) }.disabled(counter.isLocked)
                        Button("Reset", systemImage: "arrow.counterclockwise", role: .destructive) { showingResetConfirmation = true }.disabled(counter.isLocked)
                        Button("Archive", systemImage: "archivebox", role: .destructive) { showingArchiveConfirmation = true }
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { showingDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis").font(.headline.weight(.heavy)).frame(width: 38, height: 32)
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(16)
        .background(store.theme == .oled ? Color(white: 0.035) : Color.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.18), lineWidth: 1))
        .confirmationDialog("Reset \(counter.name)?", isPresented: $showingResetConfirmation) {
            Button("Reset Counter", role: .destructive) { store.safeReset(counter) }
        }
        .confirmationDialog("Archive \(counter.name)?", isPresented: $showingArchiveConfirmation) {
            Button("Archive Counter", role: .destructive) { store.archiveCounter(counter) }
        }
        .confirmationDialog("Delete \(counter.name) permanently?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Forever", role: .destructive) { store.permanentlyDeleteCounter(counter) }
        } message: {
            Text("This removes the counter, its history, and linked sessions. This cannot be undone.")
        }
        .sheet(isPresented: $showingEdit) { CounterEditorView(mode: .edit(counter)) }
    }
}

struct StepButton: View {
    let title: String
    var isDisabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.heavy)).frame(maxWidth: .infinity).frame(height: 36)
        }
        .buttonStyle(.borderedProminent).disabled(isDisabled)
    }
}
