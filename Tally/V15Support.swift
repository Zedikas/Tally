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

// MARK: - True-color selectors

struct CounterColorSelector: View {
    @Binding var selection: CounterColor
    @State private var showingChoices = false

    var body: some View {
        Button { showingChoices = true } label: {
            HStack {
                Text("Color").foregroundStyle(.primary)
                Spacer()
                Circle().fill(selection.color).frame(width: 18, height: 18)
                Text(selection.title).foregroundStyle(selection.color)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(selection.color)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingChoices, arrowEdge: .trailing) {
            ColorChoiceList(title: "Counter Color") {
                ForEach(CounterColor.allCases) { option in
                    colorChoice(title: option.title, color: option.color, selected: option == selection) {
                        selection = option
                        showingChoices = false
                    }
                }
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

struct AccentColorSelector: View {
    @Binding var selection: TallyAccentColor
    @State private var showingChoices = false

    var body: some View {
        Button { showingChoices = true } label: {
            HStack {
                Text("Accent Color").foregroundStyle(.primary)
                Spacer()
                Circle().fill(selection.color).frame(width: 18, height: 18)
                Text(selection.title).foregroundStyle(selection.color)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(selection.color)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingChoices, arrowEdge: .trailing) {
            ColorChoiceList(title: "Accent Color") {
                ForEach(TallyAccentColor.allCases) { option in
                    colorChoice(title: option.title, color: option.color, selected: option == selection) {
                        selection = option
                        showingChoices = false
                    }
                }
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct ColorChoiceList<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            Divider()
            ScrollView {
                VStack(spacing: 0) { content }
            }
        }
        .frame(width: 260, height: 390)
        .background(.regularMaterial)
    }
}

@ViewBuilder
private func colorChoice(title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle.fill")
                .foregroundStyle(color)
                .font(.title3)
            Text(title)
                .foregroundStyle(color)
                .font(.body.weight(selected ? .bold : .regular))
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
        history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counters[index].name, action: "Set to \(newValue)", delta: delta, beforeValue: before, afterValue: newValue), at: 0)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
