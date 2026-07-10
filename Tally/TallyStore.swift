import Foundation
import SwiftUI

@MainActor
final class TallyStore: ObservableObject {
    @Published var counters: [TallyCounter] = [] { didSet { save() } }
    @Published var history: [TallyHistoryEntry] = [] { didSet { save() } }
    @Published var theme: TallyTheme = .system { didSet { save() } }

    private let storageKey = "tally.state.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
        if counters.isEmpty && history.isEmpty {
            counters = Self.sampleCounters
        }
    }

    var groups: [String] {
        Array(Set(counters.map { $0.displayGroup })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func counters(in group: String) -> [TallyCounter] {
        counters.filter { $0.displayGroup == group }
    }

    func addCounter(name: String, group: String, goal: Int?, symbol: String, color: CounterColor, notes: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        counters.insert(TallyCounter(name: cleanName, value: 0, goal: goal, group: group, symbol: symbol, colorName: color.rawValue, notes: notes), at: 0)
    }

    func deleteCounter(_ counter: TallyCounter) {
        counters.removeAll { $0.id == counter.id }
        history.removeAll { $0.counterID == counter.id }
    }

    func updateCounter(_ counter: TallyCounter) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        var updated = counter
        updated.updatedAt = Date()
        counters[index] = updated
    }

    func adjust(_ counter: TallyCounter, by delta: Int) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        let before = counters[index].value
        let after = before + delta
        counters[index].value = after
        counters[index].updatedAt = Date()
        history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counters[index].name, action: delta >= 0 ? "+\(delta)" : "\(delta)", delta: delta, beforeValue: before, afterValue: after), at: 0)
    }

    func reset(_ counter: TallyCounter) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        let before = counters[index].value
        counters[index].value = 0
        counters[index].updatedAt = Date()
        history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counters[index].name, action: "Reset", delta: -before, beforeValue: before, afterValue: 0), at: 0)
    }

    func undoLastAction() {
        guard let entry = history.first,
              let index = counters.firstIndex(where: { $0.id == entry.counterID }) else { return }
        counters[index].value = entry.beforeValue
        counters[index].updatedAt = Date()
        history.removeFirst()
    }

    func clearHistory() {
        history.removeAll()
    }

    func exportJSONURL() -> URL? {
        let backup = TallyBackup(counters: counters, history: history, theme: theme)
        guard let data = try? encoder.encode(backup) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tally_Backup_\(Self.timestamp()).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func exportCSVURL() -> URL? {
        var rows = ["Date,Counter,Action,Before,After,Delta"]
        let formatter = ISO8601DateFormatter()
        for entry in history.reversed() {
            rows.append([
                formatter.string(from: entry.date),
                entry.counterName,
                entry.action,
                String(entry.beforeValue),
                String(entry.afterValue),
                String(entry.delta)
            ].map(Self.csvEscape).joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tally_History_\(Self.timestamp()).csv")
        do {
            try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func save() {
        let backup = TallyBackup(counters: counters, history: history, theme: theme)
        guard let data = try? encoder.encode(backup) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let backup = try? decoder.decode(TallyBackup.self, from: data) else { return }
        counters = backup.counters
        history = backup.history
        theme = backup.theme
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    static let sampleCounters: [TallyCounter] = [
        TallyCounter(name: "Water", value: 3, goal: 8, group: "Today", symbol: "drop.fill", colorName: CounterColor.blue.rawValue, notes: "Daily glasses"),
        TallyCounter(name: "Push-ups", value: 25, goal: 100, group: "Fitness", symbol: "figure.strengthtraining.traditional", colorName: CounterColor.green.rawValue, notes: ""),
        TallyCounter(name: "Study reps", value: 12, goal: nil, group: "Focus", symbol: "book.fill", colorName: CounterColor.purple.rawValue, notes: "")
    ]
}
