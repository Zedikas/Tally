import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TallyStore

    var body: some View {
        TabView {
            CountersView()
                .tabItem { Label("Counters", systemImage: "number.circle.fill") }
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

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        quickStats
                        ForEach(store.groups, id: \.self) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group)
                                    .font(.headline.weight(.heavy))
                                    .padding(.horizontal)
                                ForEach(store.counters(in: group)) { counter in
                                    CounterCard(counter: counter)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Tally")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { store.undoLastAction() } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(store.history.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Label("New", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { CounterEditorView(mode: .add) }
        }
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
            StatPill(title: "Counters", value: "\(store.counters.count)", systemImage: "number")
            StatPill(title: "Today", value: "\(store.history.filter { Calendar.current.isDateInToday($0.date) }.count)", systemImage: "calendar")
            StatPill(title: "Total", value: "\(store.counters.map(\.value).reduce(0,+))", systemImage: "sum")
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
                StepButton(title: "+1") { store.adjust(counter, by: 1) }
                StepButton(title: "+5") { store.adjust(counter, by: 5) }
                StepButton(title: "+10") { store.adjust(counter, by: 10) }
                Menu {
                    Button("+100") { store.adjust(counter, by: 100) }
                    Button("Reset", role: .destructive) { showingResetConfirmation = true }
                    Button("Edit") { showingEdit = true }
                    Button("Delete", role: .destructive) { store.deleteCounter(counter) }
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
