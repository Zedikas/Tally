import Foundation
import SwiftUI

struct TallyCounter: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var value: Int
    var goal: Int?
    var group: String
    var symbol: String
    var colorName: CounterColor.RawValue
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var stepValues: [Int]

    init(
        id: UUID = UUID(),
        name: String,
        value: Int,
        goal: Int?,
        group: String,
        symbol: String,
        colorName: CounterColor.RawValue,
        notes: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        stepValues: [Int] = [1, 5, 10]
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.goal = goal
        self.group = group
        self.symbol = symbol
        self.colorName = colorName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.stepValues = Self.sanitizedStepValues(stepValues)
    }

    var displayGroup: String {
        group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : group
    }

    var progress: Double? {
        guard let goal, goal > 0 else { return nil }
        return min(max(Double(value) / Double(goal), 0), 1)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, value, goal, group, symbol, colorName, notes, createdAt, updatedAt, isArchived, stepValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(Int.self, forKey: .value)
        goal = try container.decodeIfPresent(Int.self, forKey: .goal)
        group = try container.decode(String.self, forKey: .group)
        symbol = try container.decode(String.self, forKey: .symbol)
        colorName = try container.decode(CounterColor.RawValue.self, forKey: .colorName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        stepValues = Self.sanitizedStepValues(try container.decodeIfPresent([Int].self, forKey: .stepValues) ?? [1, 5, 10])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(goal, forKey: .goal)
        try container.encode(group, forKey: .group)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(colorName, forKey: .colorName)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(Self.sanitizedStepValues(stepValues), forKey: .stepValues)
    }

    static func sanitizedStepValues(_ values: [Int]) -> [Int] {
        let cleaned = values
            .filter { $0 > 0 }
            .map { min($0, 9999) }
        var unique: [Int] = []
        for value in cleaned where !unique.contains(value) {
            unique.append(value)
        }
        let result = Array(unique.prefix(3))
        return result.isEmpty ? [1, 5, 10] : result
    }
}

struct TallyHistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var counterID: UUID
    var counterName: String
    var action: String
    var delta: Int
    var beforeValue: Int
    var afterValue: Int
    var date: Date = Date()
}

enum CounterColor: String, CaseIterable, Codable, Identifiable {
    case blue, purple, pink, green, orange, red, teal, gray
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        case .gray: return .gray
        }
    }
}

enum CounterSort: String, CaseIterable, Identifiable {
    case manual, recent, name, value
    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return "Manual"
        case .recent: return "Recently Updated"
        case .name: return "Name"
        case .value: return "Value"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: return "line.3.horizontal"
        case .recent: return "clock.arrow.circlepath"
        case .name: return "textformat.abc"
        case .value: return "number"
        }
    }
}

enum TallyTheme: String, CaseIterable, Codable, Identifiable {
    case system, light, dark, oled
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .oled: return "OLED Black"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark, .oled: return .dark
        }
    }
}

struct CounterTemplate: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var name: String
    var group: String
    var goal: Int?
    var symbol: String
    var color: CounterColor
    var notes: String
    var stepValues: [Int]

    static let allCases: [CounterTemplate] = [
        CounterTemplate(id: "simple", title: "Simple Tally", subtitle: "Basic count-up tracker", name: "New Counter", group: "General", goal: nil, symbol: "number.circle.fill", color: .blue, notes: "", stepValues: [1, 5, 10]),
        CounterTemplate(id: "daily-goal", title: "Daily Goal", subtitle: "Track progress toward a target", name: "Daily Goal", group: "Today", goal: 10, symbol: "checkmark.circle.fill", color: .green, notes: "Resets manually for now.", stepValues: [1, 2, 5]),
        CounterTemplate(id: "water", title: "Water", subtitle: "Daily glasses or bottles", name: "Water", group: "Today", goal: 8, symbol: "drop.fill", color: .blue, notes: "Daily hydration", stepValues: [1, 2, 4]),
        CounterTemplate(id: "workout", title: "Workout Reps", subtitle: "Sets, reps, or exercises", name: "Workout Reps", group: "Fitness", goal: 100, symbol: "figure.strengthtraining.traditional", color: .green, notes: "", stepValues: [1, 10, 25]),
        CounterTemplate(id: "inventory", title: "Inventory", subtitle: "Stock or item tracking", name: "Inventory", group: "Inventory", goal: nil, symbol: "shippingbox.fill", color: .orange, notes: "Use + and − to adjust stock.", stepValues: [1, 5, 20]),
        CounterTemplate(id: "score", title: "Game Score", subtitle: "Simple score counter", name: "Player Score", group: "Games", goal: nil, symbol: "gamecontroller.fill", color: .purple, notes: "", stepValues: [1, 2, 3]),
        CounterTemplate(id: "reading", title: "Reading", subtitle: "Pages, chapters, or sessions", name: "Reading", group: "Focus", goal: 50, symbol: "book.fill", color: .purple, notes: "", stepValues: [1, 5, 10]),
        CounterTemplate(id: "streak", title: "Streak", subtitle: "Count days or wins", name: "Streak", group: "Habits", goal: nil, symbol: "flame.fill", color: .red, notes: "", stepValues: [1, 7, 30]),
        CounterTemplate(id: "shopping", title: "Shopping List", subtitle: "Items collected or packed", name: "Items", group: "Shopping", goal: nil, symbol: "cart.fill", color: .teal, notes: "", stepValues: [1, 5, 10])
    ]
}

struct TallyBackup: Codable {
    var version: String = "1.3"
    var exportedAt: Date = Date()
    var counters: [TallyCounter]
    var history: [TallyHistoryEntry]
    var theme: TallyTheme
}

struct TallyBackupPreview: Identifiable {
    let id = UUID()
    let url: URL
    let version: String
    let exportedAt: Date
    let counterCount: Int
    let activeCounterCount: Int
    let archivedCounterCount: Int
    let historyCount: Int
    let themeTitle: String
}
