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

struct TallyBackup: Codable {
    var version: String = "1.0"
    var exportedAt: Date = Date()
    var counters: [TallyCounter]
    var history: [TallyHistoryEntry]
    var theme: TallyTheme
}
