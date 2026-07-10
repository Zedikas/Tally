import SwiftUI

enum CounterEditorMode: Identifiable {
    case add
    case edit(TallyCounter)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let counter): return counter.id.uuidString
        }
    }
}

struct CounterEditorView: View {
    @EnvironmentObject private var store: TallyStore
    @Environment(\.dismiss) private var dismiss

    let mode: CounterEditorMode
    @State private var name: String = ""
    @State private var group: String = "General"
    @State private var goalText: String = ""
    @State private var symbol: String = "number.circle.fill"
    @State private var color: CounterColor = .blue
    @State private var notes: String = ""

    private let symbols = [
        "number.circle.fill", "checkmark.circle.fill", "drop.fill", "flame.fill", "bolt.fill",
        "book.fill", "cart.fill", "gamecontroller.fill", "figure.strengthtraining.traditional", "star.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Counter") {
                    TextField("Name", text: $name)
                    TextField("Group", text: $group)
                    TextField("Optional goal", text: $goalText)
                        .keyboardType(.numberPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section("Style") {
                    Picker("Color", selection: $color) {
                        ForEach(CounterColor.allCases) { color in
                            Label(color.title, systemImage: "circle.fill").tag(color)
                        }
                    }
                    Picker("Symbol", selection: $symbol) {
                        ForEach(symbols, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private var title: String {
        switch mode {
        case .add: return "New Counter"
        case .edit: return "Edit Counter"
        }
    }

    private func populate() {
        guard case .edit(let counter) = mode else { return }
        name = counter.name
        group = counter.group
        goalText = counter.goal.map(String.init) ?? ""
        symbol = counter.symbol
        color = CounterColor(rawValue: counter.colorName) ?? .blue
        notes = counter.notes
    }

    private func save() {
        let goal = Int(goalText.trimmingCharacters(in: .whitespacesAndNewlines))
        switch mode {
        case .add:
            store.addCounter(name: name, group: group, goal: goal, symbol: symbol, color: color, notes: notes)
        case .edit(var counter):
            counter.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            counter.group = group
            counter.goal = goal
            counter.symbol = symbol
            counter.colorName = color.rawValue
            counter.notes = notes
            store.updateCounter(counter)
        }
        dismiss()
    }
}
