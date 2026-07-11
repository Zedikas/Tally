import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TallyStore
    @AppStorage(StoredAccentColor.presetKey) private var accentColorRaw = TallyAccentColor.blue.rawValue
    @AppStorage(StoredAccentColor.customKey) private var customAccentHex = "FF1883"
    @State private var showingOnboarding = false

    var body: some View {
        TabView {
            CountersView()
                .tabItem { Label("Counters", systemImage: "number.circle.fill") }
            SessionsView()
                .tabItem { Label("Sessions", systemImage: "timer") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(StoredAccentColor.resolve(accentColorRaw, customHex: customAccentHex))
        .background {
            if store.theme == .oled {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            store.ensureFoldersMigrated()
            store.performScheduledResets()
            store.rescheduleAllResetNotifications()
            if !store.preferences.onboardingCompleted {
                showingOnboarding = true
            }
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
    @State private var exactValueCounter: TallyCounter?
    @State private var searchText = ""
    @State private var sort: CounterSort = .manual

    @State private var draggingCounterID: UUID?
    @State private var dragPreviewFolderID: UUID?
    @State private var dragPreviewBeforeCounterID: UUID?
    @State private var hasDragPreviewPlacement = false
    @State private var targetedFolderID: UUID?
    @State private var targetedCounterID: UUID?
    @State private var isUnfiledTargeted = false
    @State private var lastHapticTarget: String?
    @State private var dragCleanupTask: Task<Void, Never>?
    @State private var folderExpandTask: Task<Void, Never>?

    @AppStorage("tally.collapsedFolders.v17") private var legacyCollapsedFoldersRaw = ""

    private var dragAnimation: Animation? {
        store.preferences.reducedAnimations
            ? nil
            : .interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.15)
    }

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

                        if !unfiledCounters.isEmpty || store.folders.isEmpty || isUnfiledTargeted {
                            unfiledSection
                        }

                        if visibleCounters.isEmpty && store.folders.isEmpty {
                            ContentUnavailableView(
                                searchText.isEmpty ? "No Counters or Folders" : "No Matches",
                                systemImage: "square.grid.2x2",
                                description: Text(
                                    searchText.isEmpty
                                        ? "Create a folder or a counter to begin."
                                        : "Try another search."
                                )
                            )
                            .padding(.top, 36)
                        }
                    }
                    .safeAreaPadding(.top, 8)
                    .padding(.bottom)
                    .animation(dragAnimation, value: dragPreviewFolderID)
                    .animation(dragAnimation, value: dragPreviewBeforeCounterID)
                }
            }
            .navigationTitle("Tally")
            .searchable(text: $searchText, prompt: "Search counters and folders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.undoLastAction()
                    } label: {
                        Label(
                            store.undoLabel.map { "Undo \($0)" } ?? "Undo",
                            systemImage: "arrow.uturn.backward"
                        )
                    }
                    .disabled(!store.canUndo)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(CounterSort.allCases) { option in
                                Label(option.title, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }

                        Divider()

                        Button("Expand All", systemImage: "rectangle.expand.vertical") {
                            setAllCollapsed(false)
                        }

                        Button("Collapse All", systemImage: "rectangle.compress.vertical") {
                            setAllCollapsed(true)
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                    }

                    Menu {
                        Button("New Counter", systemImage: "number.square.fill") {
                            showingAddCounter = true
                        }

                        Button("New Folder", systemImage: "folder.badge.plus") {
                            showingAddFolder = true
                        }
                    } label: {
                        Label("Create", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddCounter) {
                CounterEditorView(mode: .add)
            }
            .sheet(isPresented: $showingAddFolder) {
                FolderEditorView()
            }
            .sheet(item: $editingFolder) {
                FolderEditorView(existing: $0)
            }
            .sheet(item: $quickCreateFolder) {
                QuickFolderCreateSheet(folder: $0)
            }
            .sheet(item: $exactValueCounter) {
                ExactValueEditor(counter: $0)
            }
            .task {
                store.ensureFoldersMigrated()
            }
            .onChange(of: searchText) { _, newValue in
                expandFoldersContainingSearch(newValue)
            }
            .onDisappear {
                dragCleanupTask?.cancel()
                folderExpandTask?.cancel()
            }
        }
    }

    private func folderSection(_ folder: TallyFolder) -> some View {
        let items = counters(in: folder)
        let tint = TallyStoredColor.color(folder.colorRaw, fallback: .blue)
        let targeted = targetedFolderID == folder.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    toggleFolder(folder)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isCollapsed(folder) ? "folder.fill" : "folder.fill.badge.minus")
                            .foregroundStyle(tint)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(tint)

                            Text("\(items.count) counters • Total \(items.map(\.value).reduce(0, +))")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    quickCreateFolder = folder
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(tint)
                }
                .accessibilityLabel("Quick Create in \(folder.name)")

                Menu {
                    Button("Edit Folder", systemImage: "pencil") {
                        editingFolder = folder
                    }

                    Button("Quick Create", systemImage: "plus.circle") {
                        quickCreateFolder = folder
                    }

                    Divider()

                    Button("Delete Folder", systemImage: "trash", role: .destructive) {
                        store.deleteFolder(folder, keepCounters: true)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.secondary)
                }

                Image(systemName: isCollapsed(folder) ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal)
            .draggable("folder:\(folder.id.uuidString)") {
                FolderDragPreview(
                    folder: folder,
                    tint: tint,
                    reducedMotion: store.preferences.reducedAnimations
                )
            }

            if !isCollapsed(folder) {
                ForEach(items) { counter in
                    draggableCard(counter, targetFolder: folder)
                }

                if items.isEmpty {
                    EmptyDropTarget(
                        title: targeted ? "Release to move the counter here" : "Drop a counter here or use Quick Create.",
                        tint: tint,
                        isTargeted: targeted
                    )
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 6)
        .background(
            tint.opacity(targeted ? 0.12 : 0.035),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(tint.opacity(targeted ? 0.8 : 0), lineWidth: targeted ? 2 : 0)
        }
        .scaleEffect(targeted && !store.preferences.reducedAnimations ? 1.012 : 1)
        .shadow(
            color: tint.opacity(targeted ? 0.2 : 0),
            radius: targeted ? 14 : 0,
            x: 0,
            y: 4
        )
        .dropDestination(for: String.self) { values, _ in
            let handled = handleDrop(values, onto: folder)
            finishDrag(didLand: handled)
            return handled
        } isTargeted: { isTargeted in
            updateFolderTarget(folder, isTargeted: isTargeted)
        }
        .animation(dragAnimation, value: targeted)
        .animation(dragAnimation, value: isCollapsed(folder))
    }

    private var unfiledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Unfiled", systemImage: "tray")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(isUnfiledTargeted ? Color.accentColor : Color.secondary)

                Spacer()

                Text(
                    isUnfiledTargeted
                        ? "Release to remove from folder"
                        : "Drop here to remove from a folder"
                )
                .font(.caption2.weight(isUnfiledTargeted ? .semibold : .regular))
                .foregroundStyle(
                    isUnfiledTargeted
                        ? Color.accentColor
                        : Color.secondary.opacity(0.68)
                )
            }
            .padding(.horizontal)

            ForEach(unfiledCounters) { counter in
                draggableCard(counter, targetFolder: nil)
            }

            if unfiledCounters.isEmpty {
                EmptyDropTarget(
                    title: isUnfiledTargeted ? "Release to move to Unfiled" : "Drop counters here",
                    tint: Color.accentColor,
                    isTargeted: isUnfiledTargeted
                )
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 6)
        .background(
            Color.accentColor.opacity(isUnfiledTargeted ? 0.055 : 0),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .dropDestination(for: String.self) { values, _ in
            guard let payload = values.first,
                  let counter = counter(from: payload) else {
                finishDrag(didLand: false)
                return false
            }

            withAnimation(dragAnimation) {
                store.moveCounter(counter, to: nil)
            }
            finishDrag(didLand: true)
            return true
        } isTargeted: { targeted in
            updateUnfiledTarget(targeted)
        }
        .animation(dragAnimation, value: isUnfiledTargeted)
    }

    private func draggableCard(_ counter: TallyCounter, targetFolder: TallyFolder?) -> some View {
        let isDragging = draggingCounterID == counter.id
        let isInsertionTarget = targetedCounterID == counter.id && draggingCounterID != counter.id
        let targetTint: Color

        if let targetFolder {
            targetTint = TallyStoredColor.color(targetFolder.colorRaw, fallback: .blue)
        } else {
            targetTint = TallyStoredColor.color(counter.colorName)
        }

        return CounterCard(
            counter: counter,
            showsDragHandle: sort == .manual,
            onEditExactValue: {
                exactValueCounter = counter
            }
        )
        .padding(.horizontal)
        .scaleEffect(isDragging && !store.preferences.reducedAnimations ? 0.97 : 1)
        .opacity(isDragging ? 0.4 : 1)
        .saturation(isDragging ? 0.75 : 1)
        .overlay(alignment: .top) {
            if isInsertionTarget {
                Capsule()
                    .fill(targetTint)
                    .frame(height: 4)
                    .padding(.horizontal, 24)
                    .offset(y: -8)
                    .shadow(color: targetTint.opacity(0.5), radius: 5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .draggable("counter:\(counter.id.uuidString)") {
            CounterDragPreview(
                counter: counter,
                color: TallyStoredColor.color(counter.colorName),
                reducedMotion: store.preferences.reducedAnimations
            )
            .onAppear {
                beginCounterDrag(counter)
            }
            .onDisappear {
                scheduleDragCleanup(for: counter.id)
            }
        }
        .dropDestination(for: String.self) { values, _ in
            guard sort == .manual,
                  let payload = values.first,
                  let source = self.counter(from: payload),
                  source.id != counter.id else {
                finishDrag(didLand: false)
                return false
            }

            withAnimation(dragAnimation) {
                store.moveCounter(source, before: counter, to: targetFolder)
            }
            finishDrag(didLand: true)
            return true
        } isTargeted: { targeted in
            updateCounterTarget(counter, in: targetFolder, isTargeted: targeted)
        }
        .animation(dragAnimation, value: isDragging)
        .animation(dragAnimation, value: isInsertionTarget)
    }

    private func handleDrop(_ values: [String], onto folder: TallyFolder) -> Bool {
        guard let payload = values.first else { return false }

        if let sourceCounter = counter(from: payload) {
            withAnimation(dragAnimation) {
                store.moveCounter(sourceCounter, to: folder)
            }
            return true
        }

        if let sourceFolder = folder(from: payload), sourceFolder.id != folder.id {
            withAnimation(dragAnimation) {
                store.moveFolder(sourceFolder, before: folder)
            }
            return true
        }

        return false
    }

    private func beginCounterDrag(_ counter: TallyCounter) {
        dragCleanupTask?.cancel()
        guard draggingCounterID != counter.id else { return }

        withAnimation(dragAnimation) {
            draggingCounterID = counter.id
            dragPreviewFolderID = resolvedFolderID(for: counter)
            dragPreviewBeforeCounterID = nil
            hasDragPreviewPlacement = false
            targetedFolderID = nil
            targetedCounterID = nil
            isUnfiledTargeted = false
        }

        lastHapticTarget = nil
        store.performHaptic(.light)
    }

    private func updateCounterTarget(
        _ target: TallyCounter,
        in folder: TallyFolder?,
        isTargeted: Bool
    ) {
        guard sort == .manual, draggingCounterID != nil else { return }

        if isTargeted {
            guard draggingCounterID != target.id else { return }

            let newFolderID = folder?.id
            let didChange = targetedCounterID != target.id || dragPreviewFolderID != newFolderID

            withAnimation(dragAnimation) {
                targetedCounterID = target.id
                targetedFolderID = folder?.id
                isUnfiledTargeted = folder == nil
                dragPreviewFolderID = newFolderID
                dragPreviewBeforeCounterID = target.id
                hasDragPreviewPlacement = true
            }

            if didChange {
                hapticCheckpoint("counter:\(target.id.uuidString)")
            }
        } else if targetedCounterID == target.id {
            withAnimation(dragAnimation) {
                targetedCounterID = nil
            }
        }
    }

    private func updateFolderTarget(_ folder: TallyFolder, isTargeted: Bool) {
        if isTargeted {
            withAnimation(dragAnimation) {
                targetedFolderID = folder.id
                isUnfiledTargeted = false
            }

            hapticCheckpoint("folder:\(folder.id.uuidString)")
            scheduleAutoExpand(folder)

            if draggingCounterID != nil && (isCollapsed(folder) || baseCounters(in: folder.id).isEmpty) {
                withAnimation(dragAnimation) {
                    dragPreviewFolderID = folder.id
                    dragPreviewBeforeCounterID = nil
                    hasDragPreviewPlacement = true
                }
            }
        } else if targetedFolderID == folder.id {
            folderExpandTask?.cancel()
            withAnimation(dragAnimation) {
                targetedFolderID = nil
            }
        }
    }

    private func updateUnfiledTarget(_ targeted: Bool) {
        withAnimation(dragAnimation) {
            isUnfiledTargeted = targeted

            if targeted {
                targetedFolderID = nil

                if draggingCounterID != nil && targetedCounterID == nil {
                    dragPreviewFolderID = nil
                    dragPreviewBeforeCounterID = nil
                    hasDragPreviewPlacement = true
                }
            }
        }

        if targeted {
            hapticCheckpoint("unfiled")
        }
    }

    private func scheduleAutoExpand(_ folder: TallyFolder) {
        folderExpandTask?.cancel()
        guard isCollapsed(folder), draggingCounterID != nil else { return }

        folderExpandTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 525_000_000)

            guard !Task.isCancelled,
                  targetedFolderID == folder.id,
                  isCollapsed(folder) else {
                return
            }

            setFolder(folder, collapsed: false)
            store.performHaptic(.selection)
        }
    }

    private func scheduleDragCleanup(for counterID: UUID) {
        dragCleanupTask?.cancel()

        dragCleanupTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)

            guard !Task.isCancelled, draggingCounterID == counterID else {
                return
            }

            finishDrag(didLand: false)
        }
    }

    private func finishDrag(didLand: Bool) {
        dragCleanupTask?.cancel()
        folderExpandTask?.cancel()

        if didLand {
            store.performHaptic(.success)
        }

        withAnimation(dragAnimation) {
            draggingCounterID = nil
            dragPreviewFolderID = nil
            dragPreviewBeforeCounterID = nil
            hasDragPreviewPlacement = false
            targetedFolderID = nil
            targetedCounterID = nil
            isUnfiledTargeted = false
        }

        lastHapticTarget = nil
    }

    private func hapticCheckpoint(_ key: String) {
        guard lastHapticTarget != key else { return }
        lastHapticTarget = key
        store.performHaptic(.selection)
    }

    private func counter(from payload: String) -> TallyCounter? {
        let raw: String

        if payload.hasPrefix("counter:") {
            raw = String(payload.dropFirst("counter:".count))
        } else {
            raw = payload
        }

        guard let id = UUID(uuidString: raw) else { return nil }
        return store.counters.first { $0.id == id }
    }

    private func folder(from payload: String) -> TallyFolder? {
        guard payload.hasPrefix("folder:") else { return nil }
        let raw = String(payload.dropFirst("folder:".count))
        guard let id = UUID(uuidString: raw) else { return nil }
        return store.folder(id: id)
    }

    private var collapsedFolderIDs: Set<UUID> {
        var values = Set(store.preferences.collapsedFolderIDs)

        for raw in legacyCollapsedFoldersRaw.split(separator: "\n") {
            if let id = UUID(uuidString: String(raw)) {
                values.insert(id)
            }
        }

        return values
    }

    private func isCollapsed(_ folder: TallyFolder) -> Bool {
        collapsedFolderIDs.contains(folder.id)
    }

    private func toggleFolder(_ folder: TallyFolder) {
        setFolder(folder, collapsed: !isCollapsed(folder))
    }

    private func setFolder(_ folder: TallyFolder, collapsed: Bool) {
        var values = collapsedFolderIDs

        if collapsed {
            values.insert(folder.id)
        } else {
            values.remove(folder.id)
        }

        withAnimation(dragAnimation) {
            store.preferences.collapsedFolderIDs = Array(values)
            legacyCollapsedFoldersRaw = ""
        }
    }

    private func setAllCollapsed(_ collapsed: Bool) {
        withAnimation(dragAnimation) {
            store.preferences.collapsedFolderIDs = collapsed ? store.folders.map(\.id) : []
            legacyCollapsedFoldersRaw = ""
        }
    }

    private func expandFoldersContainingSearch(_ raw: String) {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let matchingIDs = Set(
            store.activeCounters.compactMap { counter -> UUID? in
                let matches = counter.name.localizedCaseInsensitiveContains(query)
                    || counter.notes.localizedCaseInsensitiveContains(query)
                    || counter.displayGroup.localizedCaseInsensitiveContains(query)
                return matches ? resolvedFolderID(for: counter) : nil
            }
        )

        guard !matchingIDs.isEmpty else { return }

        var collapsed = collapsedFolderIDs
        collapsed.subtract(matchingIDs)

        withAnimation(dragAnimation) {
            store.preferences.collapsedFolderIDs = Array(collapsed)
            legacyCollapsedFoldersRaw = ""
        }
    }

    private var filteredCounters: [TallyCounter] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return store.activeCounters
        }

        return store.activeCounters.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.displayGroup.localizedCaseInsensitiveContains(trimmed)
                || $0.notes.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var visibleCounters: [TallyCounter] {
        sortCounters(filteredCounters)
    }

    private var visibleFolders: [TallyFolder] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let values: [TallyFolder]
        if trimmed.isEmpty {
            values = store.folders
        } else {
            values = store.folders.filter { folder in
                folder.name.localizedCaseInsensitiveContains(trimmed)
                    || filteredCounters.contains { resolvedFolderID(for: $0) == folder.id }
            }
        }

        return values.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var unfiledCounters: [TallyCounter] {
        displayedCounters(in: nil)
    }

    private func counters(in folder: TallyFolder) -> [TallyCounter] {
        displayedCounters(in: folder.id)
    }

    private func baseCounters(in folderID: UUID?) -> [TallyCounter] {
        sortCounters(
            filteredCounters.filter { resolvedFolderID(for: $0) == folderID }
        )
    }

    private func displayedCounters(in folderID: UUID?) -> [TallyCounter] {
        var values = baseCounters(in: folderID)

        guard sort == .manual,
              let draggingCounterID,
              hasDragPreviewPlacement,
              let moving = filteredCounters.first(where: { $0.id == draggingCounterID }) else {
            return values
        }

        values.removeAll { $0.id == draggingCounterID }

        if dragPreviewFolderID == folderID {
            if let beforeID = dragPreviewBeforeCounterID,
               let index = values.firstIndex(where: { $0.id == beforeID }) {
                values.insert(moving, at: index)
            } else {
                values.append(moving)
            }
        }

        let pinned = values.filter { $0.isPinned }
        let regular = values.filter { !$0.isPinned }
        return pinned + regular
    }

    private func resolvedFolderID(for counter: TallyCounter) -> UUID? {
        if let id = counter.folderID, store.folder(id: id) != nil {
            return id
        }

        return store.folder(named: counter.group)?.id
    }

    private func sortCounters(_ values: [TallyCounter]) -> [TallyCounter] {
        values.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            switch sort {
            case .manual:
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.createdAt < rhs.createdAt
                }
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
            if store.theme == .oled {
                Color.black.ignoresSafeArea()
            } else if store.theme == .dark {
                Color(red: 0.055, green: 0.055, blue: 0.065)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            StatPill(
                title: "Active",
                value: "\(store.activeCounters.count)",
                systemImage: "number"
            )
            StatPill(
                title: "Folders",
                value: "\(store.folders.count)",
                systemImage: "folder"
            )
            StatPill(
                title: "Total",
                value: "\(visibleCounters.map(\.value).reduce(0, +))",
                systemImage: "sum"
            )
        }
        .padding(.horizontal)
    }
}

private struct EmptyDropTarget: View {
    let title: String
    let tint: Color
    let isTargeted: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(isTargeted ? .semibold : .regular))
            .foregroundStyle(isTargeted ? tint : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isTargeted ? 25 : 18)
            .background(
                tint.opacity(isTargeted ? 0.14 : 0.06),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        tint.opacity(isTargeted ? 0.75 : 0),
                        style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                    )
            }
    }
}
