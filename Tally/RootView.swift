import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TallyStore

    var body: some View {
        TabView {
            CountersView()
                .tabItem { Label("Counters", systemImage: "number.circle.fill") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
        .background(store.theme == .oled ? Color.black : Color.clear)
    }
}

struct CountersView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var showingAdd = false
    @State private var searchText = ""
    @State private var sort: CounterSort = .manual

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        quickStats
                        if visibleCounters.isEmpty {
                            ContentUnavailableView(
                                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No Active Counters" : "No Matches",
                                systemImage: "magnifyingglass",
                                description: Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Create a counter or restore one from the archive." : "Try a different name, group, or note.")
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(visibleGroups, id: \.self) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(group)
                                            .font(.headline.weight(.heavy))
                                        Spacer()
                                        Text("\(counters(in: group).count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(.thinMaterial, in: Capsule())
                                    }
                                    .padding(.horizontal)

                                    ForEach(counters(in: group)) { counter in
                                        CounterCard(counter: counter)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Tally")
            .searchable(text: $searchText, prompt: "Search counters")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { store.undoLastAction() } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(store.history.isEmpty)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(CounterSort.allCases) { option in
                                Label(option.title, systemImage: option.systemImage).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                    }

                    Button { showingAdd = true } label: {
                        Label("New", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { CounterEditorView(mode: .add) }
        }
    }

    private var visibleCounters: [TallyCounter] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [TallyCounter]
        if trimmed.isEmpty {
            filtered = store.activeCounters
        } else {
            filtered = store.activeCounters.filter { counter in
                counter.name.localizedCaseInsensitiveContains(trimmed) ||
                counter.displayGroup.localizedCaseInsensitiveContains(trimmed) ||
                counter.notes.localizedCaseInsensitiveContains(trimmed)
            }
        }

        switch sort {
        case .manual:
            return filtered
        case .recent:
            return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .value:
            return filtered.sorted { $0.value > $1.value }
        }
    }

    private var visibleGroups: [String] {
        store.groups(for: visibleCounters)
    }

    private func counters(in group: String) -> [TallyCounter] {
        visibleCounters.filter { $0.displayGroup == group }
    }

    private var background: some View {
        Group {
            if store.theme == .oled {
                Color.black.ignoresSafeArea()
            } else {
                LinearGradient(colors: [Color(.systemBackground), Color.blue.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
        }
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            StatPill(title: "Active", value: "\(store.activeCounters.count)", systemImage: "number")
            StatPill(title: "Archived", value: "\(store.archivedCounters.count)", systemImage: "archivebox")
            StatPill(title: "Total", value: "\(visibleCounters.map(\.value).reduce(0,+))", systemImage: "sum")
        }
        .padding(.horizontal)
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.black))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CounterCard: View {
    @EnvironmentObject private var store: TallyStore
    let counter: TallyCounter
    @State private var showingEdit = false
    @State private var showingResetConfirmation = false
    @State private var showingArchiveConfirmation = false

    var color: CounterColor { CounterColor(rawValue: counter.colorName) ?? .blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: counter.symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color.color)
                    .frame(width: 44, height: 44)
                    .background(color.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(counter.name).font(.headline.weight(.heavy))
                    if let goal = counter.goal, goal > 0 {
                        Text("Goal: \(counter.value) / \(goal)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if !counter.notes.isEmpty {
                        Text(counter.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(counter.value)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(color.color)
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }

            if let progress = counter.progress {
                ProgressView(value: progress)
                    .tint(color.color)
            }

            HStack(spacing: 8) {
                StepButton(title: "−1") { store.adjust(counter, by: -1) }
                ForEach(Array(counter.stepValues.enumerated()), id: \.offset) { _, step in
                    StepButton(title: "+\(step)") { store.adjust(counter, by: step) }
                }
                Menu {
                    Button("+100") { store.adjust(counter, by: 100) }
                    Divider()
                    Button("Duplicate") { store.duplicateCounter(counter) }
                    Button("Move Up") { store.moveCounter(counter, by: -1) }
                    Button("Move Down") { store.moveCounter(counter, by: 1) }
                    Divider()
                    Button("Reset", role: .destructive) { showingResetConfirmation = true }
                    Button("Edit") { showingEdit = true }
                    Button("Archive", role: .destructive) { showingArchiveConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.heavy))
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(color.color.opacity(0.18), lineWidth: 1))
        .confirmationDialog("Reset \(counter.name)?", isPresented: $showingResetConfirmation) {
            Button("Reset Counter", role: .destructive) { store.reset(counter) }
        }
        .confirmationDialog("Archive \(counter.name)?", isPresented: $showingArchiveConfirmation) {
            Button("Archive Counter", role: .destructive) { store.archiveCounter(counter) }
        } message: {
            Text("Archived counters disappear from the main list but can be restored from Settings.")
        }
        .sheet(isPresented: $showingEdit) { CounterEditorView(mode: .edit(counter)) }
    }
}

struct StepButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
        }
        .buttonStyle(.borderedProminent)
    }
}
