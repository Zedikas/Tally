import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Stored appearance

enum StoredAccentColor {
    static let presetKey = "tally.accentColor"
    static let customKey = "tally.customAccentHex"

    static func resolve(_ raw: String, customHex: String) -> Color {
        if raw == "custom" { return Color(hex: customHex) ?? .pink }
        return TallyAccentColor(rawValue: raw)?.color ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let value = UInt64(clean, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    func hexString() -> String? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #else
        return nil
        #endif
    }
}

// MARK: - Stable page-based selectors

struct CounterColorSelectionView: View {
    @Binding var selection: CounterColor
    let title: String

    var body: some View {
        List {
            Section {
                ForEach(CounterColor.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        HStack(spacing: 14) {
                            Circle().fill(option.color).frame(width: 28, height: 28)
                            Text(option.title).foregroundStyle(option.color).font(.headline)
                            Spacer()
                            if option == selection {
                                Image(systemName: "checkmark").font(.headline.weight(.bold)).foregroundStyle(option.color)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SymbolSelectionView: View {
    @Binding var selection: String

    var body: some View {
        List {
            Section("Symbols") {
                ForEach(CounterSymbolOption.all) { option in
                    Button {
                        selection = option.symbol
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.symbol).frame(width: 30).font(.title3)
                            Text(option.title).foregroundStyle(.primary)
                            Spacer()
                            if option.symbol == selection { Image(systemName: "checkmark").fontWeight(.bold) }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Symbol")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Store safety, milestones, folders, and automatic resets

extension TallyStore {
    func counter(withID id: UUID) -> TallyCounter? { counters.first { $0.id == id } }

    func safeAdjust(_ counter: TallyCounter, by delta: Int) {
        guard !counter.isLocked else { return }
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        let before = counters[index].value
        let after = before + delta
        counters[index].value = after
        counters[index].updatedAt = Date()
        history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counters[index].name, action: delta >= 0 ? "+\(delta)" : "\(delta)", delta: delta, beforeValue: before, afterValue: after), at: 0)
        recordNewMilestones(at: index, previousValue: before)
    }

    func safeSetExactValue(_ counter: TallyCounter, to newValue: Int) {
        guard !counter.isLocked else { return }
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        let before = counters[index].value
        guard before != newValue else { return }
        counters[index].value = newValue
        counters[index].updatedAt = Date()
        history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counters[index].name, action: "Set to \(newValue)", delta: newValue - before, beforeValue: before, afterValue: newValue), at: 0)
        recordNewMilestones(at: index, previousValue: before)
    }

    func safeReset(_ counter: TallyCounter, automatic: Bool = false) {
        guard !counter.isLocked || automatic else { return }
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        let before = counters[index].value
        guard before != 0 else {
            counters[index].lastAutomaticResetAt = automatic ? Date() : counters[index].lastAutomaticResetAt
            return
        }
        counters[index].value = 0
        counters[index].updatedAt = Date()
        if automatic { counters[index].lastAutomaticResetAt = Date() }
        history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counters[index].name, action: automatic ? "Automatic Reset" : "Reset", delta: -before, beforeValue: before, afterValue: 0), at: 0)
    }

    func togglePinned(_ counter: TallyCounter) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        counters[index].isPinned.toggle()
        counters[index].updatedAt = Date()
    }

    func toggleLocked(_ counter: TallyCounter) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        counters[index].isLocked.toggle()
        counters[index].updatedAt = Date()
    }

    func folderColor(for group: String) -> CounterColor {
        let raw = activeCounters.first(where: { $0.displayGroup == group })?.folderColorName
        return CounterColor(rawValue: raw ?? CounterColor.gray.rawValue) ?? .gray
    }

    func updateFolderColor(group: String, color: CounterColor) {
        for index in counters.indices where counters[index].displayGroup == group {
            counters[index].folderColorName = color.rawValue
        }
    }

    func performAutomaticResets(now: Date = Date()) {
        let calendar = Calendar.current
        for counter in counters where !counter.isArchived && counter.automaticResetEnabled && counter.resetReminder != .none {
            let last = counter.lastAutomaticResetAt ?? counter.updatedAt
            let shouldReset: Bool
            switch counter.resetReminder {
            case .none: shouldReset = false
            case .daily: shouldReset = !calendar.isDate(last, inSameDayAs: now)
            case .weekly:
                shouldReset = calendar.component(.weekOfYear, from: last) != calendar.component(.weekOfYear, from: now) || calendar.component(.yearForWeekOfYear, from: last) != calendar.component(.yearForWeekOfYear, from: now)
            case .monthly:
                shouldReset = calendar.component(.month, from: last) != calendar.component(.month, from: now) || calendar.component(.year, from: last) != calendar.component(.year, from: now)
            }
            if shouldReset { safeReset(counter, automatic: true) }
        }
    }

    private func recordNewMilestones(at index: Int, previousValue: Int) {
        let current = counters[index].value
        let newlyReached = counters[index].milestones.filter { milestone in
            previousValue < milestone && current >= milestone && !counters[index].reachedMilestones.contains(milestone)
        }
        guard !newlyReached.isEmpty else { return }
        for milestone in newlyReached {
            counters[index].reachedMilestones.append(milestone)
            history.insert(TallyHistoryEntry(counterID: counters[index].id, counterName: counters[index].name, action: "Milestone \(milestone) 🎉", delta: 0, beforeValue: current, afterValue: current), at: 0)
        }
    }
}

// MARK: - Counter details and analytics

struct CounterDetailView: View {
    @EnvironmentObject private var store: TallyStore
    let counterID: UUID
    @State private var showingEdit = false
    @State private var exactCounter: TallyCounter?

    private var counter: TallyCounter? { store.counter(withID: counterID) }
    private var entries: [TallyHistoryEntry] { store.history.filter { $0.counterID == counterID } }
    private var sessions: [TallySession] { store.sessions.filter { $0.counterID == counterID } }

    var body: some View {
        Group {
            if let counter {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        hero(counter)
                        quickActions(counter)
                        analytics(counter)
                        if !counter.notes.isEmpty { detailSection("Notes") { Text(counter.notes).frame(maxWidth: .infinity, alignment: .leading) } }
                        detailSection("Milestones") {
                            if counter.milestones.isEmpty { Text("No milestones configured").foregroundStyle(.secondary) }
                            else {
                                ForEach(counter.milestones, id: \.self) { milestone in
                                    HStack {
                                        Label("\(milestone)", systemImage: counter.reachedMilestones.contains(milestone) ? "trophy.fill" : "trophy")
                                        Spacer()
                                        if counter.reachedMilestones.contains(milestone) { Text("Reached").foregroundStyle(.green) }
                                    }
                                }
                            }
                        }
                        detailSection("Recent History") {
                            if entries.isEmpty { Text("No history yet").foregroundStyle(.secondary) }
                            else {
                                ForEach(entries.prefix(10)) { entry in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(entry.action).fontWeight(.semibold)
                                            Text(entry.date, style: .date).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(entry.beforeValue) → \(entry.afterValue)").monospacedDigit()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle(counter.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showingEdit = true } }
                }
                .sheet(isPresented: $showingEdit) { CounterEditorView(mode: .edit(counter)) }
                .sheet(item: $exactCounter) { ExactValueEditor(counter: $0) }
            } else {
                ContentUnavailableView("Counter Not Found", systemImage: "questionmark.circle")
            }
        }
    }

    private func hero(_ counter: TallyCounter) -> some View {
        let color = CounterColor(rawValue: counter.colorName) ?? .blue
        return VStack(spacing: 12) {
            Image(systemName: counter.symbol).font(.system(size: 38, weight: .bold)).foregroundStyle(color.color)
            Button { exactCounter = counter } label: {
                Text("\(counter.value)").font(.system(size: 72, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(color.color)
            }.buttonStyle(.plain).disabled(counter.isLocked)
            if let goal = counter.goal, goal > 0 {
                ProgressView(value: counter.progress ?? 0).tint(color.color)
                Text("Goal \(counter.value) of \(goal)").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                if counter.isPinned { Label("Favorite", systemImage: "pin.fill") }
                if counter.isLocked { Label("Locked", systemImage: "lock.fill") }
                if counter.automaticResetEnabled { Label(counter.resetReminder.title, systemImage: counter.resetReminder.systemImage) }
            }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
    }

    private func quickActions(_ counter: TallyCounter) -> some View {
        HStack(spacing: 8) {
            StepButton(title: "−1") { store.safeAdjust(counter, by: -1) }
            ForEach(counter.stepValues, id: \.self) { step in StepButton(title: "+\(step)") { store.safeAdjust(counter, by: step) } }
        }.disabled(counter.isLocked)
    }

    private func analytics(_ counter: TallyCounter) -> some View {
        let positive = entries.filter { $0.delta > 0 }.map(\.delta).reduce(0, +)
        let activeDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
        let average = activeDays > 0 ? Double(positive) / Double(activeDays) : 0
        let daily = dailyPoints
        return detailSection("Analytics") {
            HStack {
                metric("Changes", "\(entries.count)")
                metric("Sessions", "\(sessions.count)")
                metric("Avg/Day", String(format: "%.1f", average))
            }
            if !daily.isEmpty {
                Chart(daily) { point in
                    BarMark(x: .value("Day", point.date, unit: .day), y: .value("Change", point.value))
                }
                .frame(height: 180)
            }
        }
    }

    private var dailyPoints: [CounterDailyPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries.filter { $0.delta > 0 }) { calendar.startOfDay(for: $0.date) }
        return grouped.map { CounterDailyPoint(date: $0.key, value: $0.value.map(\.delta).reduce(0, +)) }.sorted { $0.date < $1.date }.suffix(14).map { $0 }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack { Text(value).font(.title2.weight(.black)).monospacedDigit(); Text(title).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity)
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline.weight(.heavy))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct CounterDailyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}
