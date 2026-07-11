import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TallyStore
    @AppStorage(StoredAccentColor.presetKey) private var accentColorRaw = TallyAccentColor.blue.rawValue
    @AppStorage(StoredAccentColor.customKey) private var customAccentHex = "FF1883"
    @State private var showingOnboarding = false

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
            store.performScheduledResets()
            store.rescheduleAllResetNotifications()
            if !store.preferences.onboardingCompleted { showingOnboarding = true }
        }
        .sheet(isPresented: $showingOnboarding) {
            TallyOnboardingView()
                .environmentObject(store)
        }
    }
}

struct CountersView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var showingAddCounter = false
    @State private var showingAddFolder = false
    @State private var editingFolder: TallyFolder?
    @State private var quickCreateFolder: TallyFolder?
    @State private var searchText = ""
    @State private var sort: CounterSort = .manual
    @State private var exactValueCounter: TallyCounter?
    @AppStorage("tally.collapsedFolders.v17") private var legacyCollapsedFoldersRaw = ""

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        quickStats

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
                    Button { store.undoLastAction() } label: {
                        Label(store.undoLabel.map { "Undo \($0)" } ?? "Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!store.canUndo)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(CounterSort.allCases) { option in
                                Label(option.title, systemImage: option.systemImage).tag(option)
                            }
                        }
                        Divider()
                        Button("Expand All", systemImage: "rectangle.expand.vertical") { setAllCollapsed(false) }
                        Button("Collapse All", systemImage: "rectangle.compress.vertical") { setAllCollapsed(true) }
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
            .sheet(item: $quickCreateFolder) { QuickFolderCreateSheet(folder: $0) }
            .sheet(item: $exactValueCounter) { ExactValueEditor(counter: $0) }
            .task { store.ensureFoldersMigrated() }
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

                Button { quickCreateFolder = folder } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2).foregroundStyle(tint)
                }
                .accessibilityLabel("Quick Create in \(folder.name)")

                Menu {
                    Button("Edit Folder", systemImage: "pencil") { editingFolder = folder }
                    Button("Quick Create", systemImage: "plus.circle") { quickCreateFolder = folder }
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
            .draggable("folder:\(folder.id.uuidString)") {
                Label(folder.name, systemImage: "folder.fill")
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }

            if !isCollapsed(folder) {
                ForEach(items) { counter in
                    draggableCard(counter, targetFolder: folder)
                }
                if items.isEmpty {
                    Text("Drop a counter here or use Quick Create.")
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
            handleDrop(values, onto: folder)
        }
        .animation(store.preferences.reducedAnimations ? nil : .snappy, value: isCollapsed(folder))
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

            ForEach(unfiledCounters) { counter in
                draggableCard(counter, targetFolder: nil)
            }

            if unfiledCounters.isEmpty {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.secondary.opacity(0.05))
                    .frame(height: 58)
                    .overlay(Text("Drop counters here").font(.caption).foregroundStyle(.secondary))
                    .padding(.horizontal)
            }
        }
        .dropDestination(for: String.self) { values, _ in
            guard let payload = values.first,
                  let counter = counter(from: payload) else { return false }
            store.moveCounter(counter, to: nil)
            return true
        }
    }

    private func draggableCard(_ counter: TallyCounter, targetFolder: TallyFolder?) -> some View {
        CounterCard(counter: counter) { exactValueCounter = counter }
            .padding(.horizontal)
            .draggable("counter:\(counter.id.uuidString)") {
                HStack(spacing: 8) {
                    Image(systemName: counter.symbol)
                    Text(counter.name).fontWeight(.semibold)
                    if counter.isPinned { Image(systemName: "pin.fill") }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .dropDestination(for: String.self) { values, _ in
                guard sort == .manual,
                      let payload = values.first,
                      let source = self.counter(from: payload),
                      source.id != counter.id else { return false }
                store.moveCounter(source, before: counter, to: targetFolder)
                return true
            }
    }

    private func handleDrop(_ values: [String], onto folder: TallyFolder) -> Bool {
        guard let payload = values.first else { return false }
        if let sourceCounter = counter(from: payload) {
            store.moveCounter(sourceCounter, to: folder)
            return true
        }
        if let sourceFolder = folder(from: payload), sourceFolder.id != folder.id {
            store.moveFolder(sourceFolder, before: folder)
            return true
        }
        return false
    }

    private func counter(from payload: String) -> TallyCounter? {
        let raw = payload.hasPrefix("counter:") ? String(payload.dropFirst("counter:".count)) : payload
        guard let id = UUID(uuidString: raw) else { return nil }
        return store.counters.first { $0.id == id }
    }

    private func folder(from payload: String) -> TallyFolder? {
        guard payload.hasPrefix("folder:"),
              let id = UUID(uuidString: String(payload.dropFirst("folder:".count))) else { return nil }
        return store.folder(id: id)
    }

    private var collapsedFolderIDs: Set<UUID> {
        var values = Set(store.preferences.collapsedFolderIDs)
        for raw in legacyCollapsedFoldersRaw.split(separator: "\n") {
            if let id = UUID(uuidString: String(raw)) { values.insert(id) }
        }
        return values
    }

    private func isCollapsed(_ folder: TallyFolder) -> Bool {
        collapsedFolderIDs.contains(folder.id)
    }

    private func toggleFolder(_ folder: TallyFolder) {
        var values = collapsedFolderIDs
        if values.contains(folder.id) { values.remove(folder.id) }
        else { values.insert(folder.id) }
        store.preferences.collapsedFolderIDs = Array(values)
        legacyCollapsedFoldersRaw = ""
    }

    private func setAllCollapsed(_ collapsed: Bool) {
        store.preferences.collapsedFolderIDs = collapsed ? store.folders.map(\.id) : []
        legacyCollapsedFoldersRaw = ""
    }

    private var visibleCounters: [TallyCounter] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty ? store.activeCounters : store.activeCounters.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.displayGroup.localizedCaseInsensitiveContains(trimmed) ||
            $0.notes.localizedCaseInsensitiveContains(trimmed)
        }
        return sortCounters(filtered)
    }

    private var visibleFolders: [TallyFolder] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let values = trimmed.isEmpty ? store.folders : store.folders.filter { folder in
            folder.name.localizedCaseInsensitiveContains(trimmed) || visibleCounters.contains { counter in
                counter.folderID == folder.id || counter.group.localizedCaseInsensitiveCompare(folder.name) == .orderedSame
            }
        }
        return values.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var unfiledCounters: [TallyCounter] {
        sortCounters(visibleCounters.filter { counter in
            counter.folderID == nil || store.folder(id: counter.folderID) == nil
        })
    }

    private func counters(in folder: TallyFolder) -> [TallyCounter] {
        sortCounters(visibleCounters.filter {
            $0.folderID == folder.id || ($0.folderID == nil && $0.group.localizedCaseInsensitiveCompare(folder.name) == .orderedSame)
        })
    }

    private func sortCounters(_ values: [TallyCounter]) -> [TallyCounter] {
        values.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            switch sort {
            case .manual:
                if lhs.sortIndex == rhs.sortIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.sortIndex < rhs.sortIndex
            case .recent:
                return lhs.updatedAt > rhs.updatedAt
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .value:
                return lhs.value > rhs.value
            }
        }
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
    private var activeSession: TallySession? { store.activeSession(for: counter) }

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
                                if let session = activeSession {
                                    Image(systemName: session.isPaused ? "pause.circle.fill" : "timer.circle.fill")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                            }
                            if let goal = counter.goal, goal > 0 {
                                Text("Goal: \(counter.value) / \(goal)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            } else if !counter.notes.isEmpty {
                                Text(counter.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            if counter.resetReminder != .none {
                                Label(store.resetScheduleDescription(for: counter), systemImage: counter.resetReminder.systemImage)
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
            if let session = activeSession, let progress = session.progress {
                ProgressView(value: progress).tint(.orange)
            }
            HStack(spacing: 8) {
                StepButton(title: "−1", isDisabled: counter.isLocked) { store.safeAdjust(counter, by: -1) }
                ForEach(counter.stepValues, id: \.self) { step in
                    StepButton(title: "+\(step)", isDisabled: counter.isLocked) { store.safeAdjust(counter, by: step) }
                }
                Menu {
                    Button(counter.isPinned ? "Unpin" : "Pin in Folder", systemImage: counter.isPinned ? "pin.slash" : "pin") {
                        store.togglePinned(counter)
                    }
                    Button(counter.isLocked ? "Unlock" : "Lock", systemImage: counter.isLocked ? "lock.open" : "lock") {
                        store.toggleLocked(counter)
                    }
                    Button("Exact Value", systemImage: "number.square") { onEditExactValue() }.disabled(counter.isLocked)
                    if let session = activeSession {
                        if session.isPaused {
                            Button("Resume Session", systemImage: "play.circle") { store.resumeSession(session) }
                        } else {
                            Button("Pause Session", systemImage: "pause.circle") { store.pauseSession(session) }
                        }
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
            Button("Delete", role: .destructive) { store.permanentlyDeleteCounter(counter) }
        } message: {
            Text("This removes the counter, history, and linked sessions. You can use Undo until the app closes.")
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
