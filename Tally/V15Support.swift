import SwiftUI

enum TallyAccentColor: String, CaseIterable, Identifiable {
    case blue, purple, pink, green, orange, red, teal, indigo
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .blue: return Color(hex: "0A84FF") ?? .blue
        case .purple: return Color(hex: "9000FF") ?? .purple
        case .pink: return Color(hex: "FF7EFF") ?? .pink
        case .green: return Color(hex: "30D158") ?? .green
        case .orange: return Color(hex: "FF9F0A") ?? .orange
        case .red: return Color(hex: "FF453A") ?? .red
        case .teal: return Color(hex: "64D2FF") ?? .teal
        case .indigo: return Color(hex: "5E5CE6") ?? .indigo
        }
    }
}

struct CounterSymbolOption: Identifiable, Hashable {
    let symbol: String
    let title: String
    var id: String { symbol }

    static let all: [CounterSymbolOption] = [
        .init(symbol: "number.square.fill", title: "Counter"),
        .init(symbol: "checkmark.seal.fill", title: "Completed"),
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
        .init(symbol: "list.bullet.clipboard.fill", title: "Checklist"),
        .init(symbol: "dollarsign.circle.fill", title: "Money"),
        .init(symbol: "pills.fill", title: "Medication"),
        .init(symbol: "cup.and.saucer.fill", title: "Drinks"),
        .init(symbol: "figure.walk", title: "Steps"),
        .init(symbol: "graduationcap.fill", title: "Study")
    ]

    static func title(for symbol: String) -> String {
        all.first(where: { $0.symbol == symbol })?.title ?? "Custom Symbol"
    }
}

extension ResetReminder {
    var v15SystemImage: String { systemImage }
}

extension TallyStore {
    func setExactValue(_ counter: TallyCounter, to newValue: Int) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        let before = counters[index].value
        guard before != newValue else { return }
        counters[index].value = newValue
        counters[index].updatedAt = Date()
        history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counters[index].name, action: "Set to \(newValue)", delta: newValue - before, beforeValue: before, afterValue: newValue), at: 0)
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
                    Text(counter.isLocked ? "Unlock this counter before changing its value." : "Enter a positive or negative whole number. The change is recorded in History and can be undone.")
                        .font(.caption).foregroundStyle(counter.isLocked ? .orange : .secondary)
                }
            }
            .navigationTitle(counter.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        guard let value = Int(valueText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                        store.safeSetExactValue(counter, to: value)
                        dismiss()
                    }
                    .disabled(counter.isLocked || Int(valueText.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
