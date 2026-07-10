import SwiftUI

// MARK: - Global accent colors

enum TallyAccentColor: String, CaseIterable, Identifiable {
    case blue, purple, pink, green, orange, red, teal, indigo

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
        case .indigo: return .indigo
        }
    }
}

// MARK: - Human-readable symbols

struct CounterSymbolOption: Identifiable, Hashable {
    let symbol: String
    let title: String
    var id: String { symbol }

    static let all: [CounterSymbolOption] = [
        .init(symbol: "number.circle.fill", title: "Counter"),
        .init(symbol: "checkmark.circle.fill", title: "Completed"),
        .init(symbol: "drop.fill", title: "Water"),
        .init(symbol: "flame.fill", title: "Streak"),
        .init(symbol: "bolt.fill", title: "Energy"),
        .init(symbol: "book.fill", title: "Reading"),
        .init(symbol: "cart.fill", title: "Shopping"),
        .init(symbol: "gamecontroller.fill", title: "Gaming"),
        .init(symbol: "figure.strengthtraining.traditional", title: "Workout"),
        .init(symbol: "star.fill", title: "Favorite"),
        .init(symbol: "shippingbox.fill", title: "Inventory"),
        .init(symbol: "calendar", title: "Calendar"),
        .init(symbol: "trophy.fill", title: "Achievement"),
        .init(symbol: "timer", title: "Timer"),
        .init(symbol: "list.bullet.clipboard.fill", title: "Checklist")
    ]

    static func title(for symbol: String) -> String {
        all.first(where: { $0.symbol == symbol })?.title ?? "Custom Symbol"
    }
}

// MARK: - Reminder presentation

extension ResetReminder {
    var v15SystemImage: String {
        switch self {
        case .none: return "bell.slash"
        case .daily: return "1.circle.fill"
        case .weekly: return "7.circle.fill"
        case .monthly: return "30.circle.fill"
        }
    }
}

// MARK: - Exact-value editing

extension TallyStore {
    func setExactValue(_ counter: TallyCounter, to newValue: Int) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        let before = counters[index].value
        guard before != newValue else { return }
        counters[index].value = newValue
        counters[index].updatedAt = Date()
        let delta = newValue - before
        history.insert(
            TallyHistoryEntry(
                counterID: counter.id,
                counterName: counters[index].name,
                action: "Set to \(newValue)",
                delta: delta,
                beforeValue: before,
                afterValue: newValue
            ),
            at: 0
        )
    }
}

struct ExactValueEditor: View {
    @EnvironmentObject private var store: TallyStore
    @Environment(\.dismiss) private var dismiss

    let counter: TallyCounter
    @State private var valueText: String

    init(counter: TallyCounter) {
        self.counter = counter
        _valueText = State(initialValue: String(counter.value))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exact Value") {
                    TextField("Value", text: $valueText)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Enter a positive or negative whole number. The change is recorded in History and can be undone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(counter.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        guard let value = Int(valueText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                        store.setExactValue(counter, to: value)
                        dismiss()
                    }
                    .disabled(Int(valueText.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
