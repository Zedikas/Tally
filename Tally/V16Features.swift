import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Accent helpers

struct StoredAccentColor {
    static let presetKey = "tally.accentColor"
    static let customKey = "tally.customAccentHex"
    static let customValue = "custom"

    static func resolve(_ raw: String, customHex: String) -> Color {
        if raw == customValue { return Color(hex: customHex) ?? .pink }
        return TallyAccentColor(rawValue: raw)?.color ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    func hexString() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "FF1883" }
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
        #else
        return "FF1883"
        #endif
    }
}

// MARK: - Store features

extension TallyStore {
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

    func safeAdjust(_ counter: TallyCounter, by delta: Int) {
        guard let current = counters.first(where: { $0.id == counter.id }), !current.isLocked else { return }
        let before = current.value
        adjust(current, by: delta)
        registerMilestones(counterID: current.id, before: before, after: before + delta)
    }

    func safeReset(_ counter: TallyCounter) {
        guard let current = counters.first(where: { $0.id == counter.id }), !current.isLocked else { return }
        reset(current)
    }

    func safeSetExactValue(_ counter: TallyCounter, to value: Int) {
        guard let current = counters.first(where: { $0.id == counter.id }), !current.isLocked else { return }
        let before = current.value
        setExactValue(current, to: value)
        registerMilestones(counterID: current.id, before: before, after: value)
    }

    func performAutomaticResets(now: Date = Date()) {
        let calendar = Calendar.current
        for index in counters.indices where !counters[index].isArchived && counters[index].automaticResetEnabled && counters[index].resetReminder != .none {
            let counter = counters[index]
            let reference = counter.lastAutomaticResetAt ?? counter.updatedAt
            let shouldReset: Bool

            switch counter.resetReminder {
            case .none:
                shouldReset = false
            case .daily:
                shouldReset = !calendar.isDate(reference, inSameDayAs: now)
            case .weekly:
                shouldReset = calendar.component(.weekOfYear, from: reference) != calendar.component(.weekOfYear, from: now) ||
                    calendar.component(.yearForWeekOfYear, from: reference) != calendar.component(.yearForWeekOfYear, from: now)
            case .monthly:
                shouldReset = calendar.component(.month, from: reference) != calendar.component(.month, from: now) ||
                    calendar.component(.year, from: reference) != calendar.component(.year, from: now)
            }

            guard shouldReset else { continue }
            let before = counters[index].value
            counters[index].value = 0
            counters[index].lastAutomaticResetAt = now
            counters[index].updatedAt = now
            history.insert(
                TallyHistoryEntry(
                    counterID: counter.id,
                    counterName: counter.name,
                    action: "Automatic Reset",
                    delta: -before,
                    beforeValue: before,
                    afterValue: 0,
                    date: now
                ),
                at: 0
            )
        }
    }

    func updateFolderColor(group: String, color: CounterColor) {
        for index in counters.indices where counters[index].displayGroup == group {
            counters[index].folderColorName = color.rawValue
        }
    }

    func folderColor(for group: String) -> CounterColor {
        guard let raw = counters.first(where: { $0.displayGroup == group })?.folderColorName else { return .gray }
        return CounterColor(rawValue: raw) ?? .gray
    }

    private func registerMilestones(counterID: UUID, before: Int, after: Int) {
        guard let index = counters.firstIndex(where: { $0.id == counterID }) else { return }
        let newlyReached = counters[index].milestones.filter { milestone in
            before < milestone && after >= milestone && !counters[index].reachedMilestones.contains(milestone)
        }
        guard !newlyReached.isEmpty else { return }

        counters[index].reachedMilestones.append(contentsOf: newlyReached)
        counters[index].reachedMilestones = Array(Set(counters[index].reachedMilestones)).sorted()

        for milestone in newlyReached.reversed() {
            history.insert(
                TallyHistoryEntry(
                    counterID: counterID,
                    counterName: counters[index].name,
                    action: "Milestone \(milestone) 🎉",
                    delta: 0,
                    beforeValue: after,
                    afterValue: after
                ),
                at: 0
            )
        }
    }
}

// MARK: - Stable page-based selectors

struct CounterColorSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: CounterColor
    let title: String

    var body: some View {
        List {
            ForEach(CounterColor.allCases) { option in
                Button {
                    selection = option
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(option.color)
                            .frame(width: 28, height: 28)
                        Text(option.title)
                            .font(.headline)
                            .foregroundStyle(option.color)
                        Spacer()
                        if selection == option {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(option.color)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SymbolSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    var body: some View {
        List {
            ForEach(CounterSymbolOption.all) { option in
                Button {
                    selection = option.symbol
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.symbol)
                            .font(.title3)
                            .frame(width: 32)
                        Text(option.title)
                            .font(.headline)
                        Spacer()
                        if selection == option.symbol {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Symbol")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Counter details and analytics

struct CounterDetailView: View {
    @EnvironmentObject private var store: TallyStore
    let counterID: UUID
    @State private var showingEdit = false
    @State private var exactCounter: TallyCounter?

    private var counter: TallyCounter? {
        store.counters.first { $0.id == counterID }
    }

    private var entries: [TallyHistoryEntry] {
        store.history.filter { $0.counterID == counterID }
    }

    private var linkedSessions: [TallySession] {
        store.sessions.filter { $0.counterID == counterID }
    }

    private var daily: [DailyCounterPoint] {
        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped
            .map { DailyCounterPoint(date: $0.key, delta: $0.value.map(\.delta).reduce(0, +)) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        Group {
            if let counter {
                ScrollView {
                    VStack(spacing: 18) {
                        detailHeader(counter)
                        quickActions(counter)
                        analytics(counter)
                        if !daily.isEmpty { activityChart }
                        milestones(counter)
                        notes(counter)
                        recentHistory
                    }
                    .padding()
                }
                .navigationTitle(counter.name)
                .toolbar {
                    Menu {
                        Button(counter.isPinned ? "Unpin" : "Pin", systemImage: counter.isPinned ? "pin.slash" : "pin") {
                            store.togglePinned(counter)
                        }
                        Button(counter.isLocked ? "Unlock" : "Lock", systemImage: counter.isLocked ? "lock.open" : "lock") {
                            store.toggleLocked(counter)
                        }
                        Button("Edit", systemImage: "pencil") {
                            showingEdit = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .sheet(isPresented: $showingEdit) {
                    CounterEditorView(mode: .edit(counter))
                }
                .sheet(item: $exactCounter) {
                    ExactValueEditor(counter: $0)
                }
            } else {
                ContentUnavailableView("Counter Unavailable", systemImage: "number.circle")
            }
        }
    }

    private func detailHeader(_ counter: TallyCounter) -> some View {
        let tint = (CounterColor(rawValue: counter.colorName) ?? .blue).color
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: counter.symbol)
                    .font(.largeTitle)
                if counter.isPinned { Image(systemName: "pin.fill") }
                if counter.isLocked { Image(systemName: "lock.fill") }
            }
            .foregroundStyle(tint)

            Button {
                exactCounter = counter
            } label: {
                Text("\(counter.value)")
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)
            .disabled(counter.isLocked)

            if let goal = counter.goal, goal > 0 {
                Text("Goal \(counter.value) / \(goal)")
                    .foregroundStyle(.secondary)
                ProgressView(value: counter.progress ?? 0)
                    .tint(tint)
            }

            if counter.automaticResetEnabled {
                Label("Automatic \(counter.resetReminder.title) reset", systemImage: counter.resetReminder.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func quickActions(_ counter: TallyCounter) -> some View {
        HStack(spacing: 8) {
            Button("−1") { store.safeAdjust(counter, by: -1) }
            ForEach(counter.stepValues, id: \.self) { step in
                Button("+\(step)") { store.safeAdjust(counter, by: step) }
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(counter.isLocked)
    }

    private func analytics(_ counter: TallyCounter) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            DetailMetric(title: "Changes", value: "\(entries.count)")
            DetailMetric(title: "Net", value: signed(entries.map(\.delta).reduce(0, +)))
            DetailMetric(title: "Best Day", value: signed(daily.map(\.delta).max() ?? 0))
            DetailMetric(title: "Sessions", value: "\(linkedSessions.count)")
            DetailMetric(title: "Milestones", value: "\(counter.reachedMilestones.count)/\(counter.milestones.count)")
            DetailMetric(title: "Active Days", value: "\(Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count)")
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity")
                .font(.headline)
            Chart(daily.suffix(30)) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Change", point.delta)
                )
            }
            .frame(height: 180)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func milestones(_ counter: TallyCounter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Milestones")
                .font(.headline)

            if counter.milestones.isEmpty {
                Text("No milestones configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(counter.milestones, id: \.self) { milestone in
                    HStack {
                        Label(
                            "\(milestone)",
                            systemImage: counter.reachedMilestones.contains(milestone) ? "trophy.fill" : "trophy"
                        )
                        Spacer()
                        if counter.reachedMilestones.contains(milestone) {
                            Text("Reached")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func notes(_ counter: TallyCounter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(counter.notes.isEmpty ? "No notes" : counter.notes)
                .foregroundStyle(counter.notes.isEmpty ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent History")
                .font(.headline)

            if entries.isEmpty {
                Text("No history yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries.prefix(10)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.action)
                            Text(entry.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.beforeValue) → \(entry.afterValue)")
                            .monospacedDigit()
                    }
                    if entry.id != entries.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

struct DailyCounterPoint: Identifiable {
    let id = UUID()
    let date: Date
    let delta: Int
}

struct DetailMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
