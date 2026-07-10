import Foundation
import SwiftUI

struct TallyCounter: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var value: Int
    var goal: Int?
    var group: String
    var symbol: String
    var colorName: CounterColor.RawValue
    var notes: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var displayGroup: String {
        group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : group
    }

    var progress: Double? {
        guard let goal, goal > 0 else { return nil }
        return min(max(Double(value) / Double(goal), 0), 1)
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

    static let allCases: [CounterTemplate] = [
        CounterTemplate(id: "simple", title: "Simple Tally", subtitle: "Basic count-up tracker", name: "New Counter", group: "General", goal: nil, symbol: "number.circle.fill", color: .blue, notes: ""),
        CounterTemplate(id: "daily-goal", title: "Daily Goal", subtitle: "Track progress toward a target", name: "Daily Goal", group: "Today", goal: 10, symbol: "checkmark.circle.fill", color: .green, notes: "Resets manually for now."),
        CounterTemplate(id: "water", title: "Water", subtitle: "Daily glasses or bottles", name: "Water", group: "Today", goal: 8, symbol: "drop.fill", color: .blue, notes: "Daily hydration"),
        CounterTemplate(id: "workout", title: "Workout Reps", subtitle: "Sets, reps, or exercises", name: "Workout Reps", group: "Fitness", goal: 100, symbol: "figure.strengthtraining.traditional", color: .green, notes: ""),
        CounterTemplate(id: "inventory", title: "Inventory", subtitle: "Stock or item tracking", name: "Inventory", group: "Inventory", goal: nil, symbol: "shippingbox.fill", color: .orange, notes: "Use + and − to adjust stock."),
        CounterTemplate(id: "score", title: "Game Score", subtitle: "Simple score counter", name: "Player Score", group: "Games", goal: nil, symbol: "gamecontroller.fill", color: .purple, notes: ""),
        CounterTemplate(id: "reading", title: "Reading", subtitle: "Pages, chapters, or sessions", name: "Reading", group: "Focus", goal: 50, symbol: "book.fill", color: .purple, notes: ""),
        CounterTemplate(id: "streak", title: "Streak", subtitle: "Count days or wins", name: "Streak", group: "Habits", goal: nil, symbol: "flame.fill", color: .red, notes: ""),
        CounterTemplate(id: "shopping", title: "Shopping List", subtitle: "Items collected or packed", name: "Items", group: "Shopping", goal: nil, symbol: "cart.fill", color: .teal, notes: "")
    ]
}

struct TallyBackup: Codable {
    var version: String = "1.2"
    var exportedAt: Date = Date()
    var counters: [TallyCounter]
    var history: [TallyHistoryEntry]
    var theme: TallyTheme
}
