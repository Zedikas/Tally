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
    @State private var name = ""
    @State private var group = "General"
    @State private var goalText = ""
    @State private var symbol = "number.circle.fill"
    @State private var color: CounterColor = .blue
    @State private var folderColor: CounterColor = .blue
    @State private var notes = ""
    @State private var stepOneText = "1"
    @State private var stepTwoText = "5"
    @State private var stepThreeText = "10"
    @State private var resetReminder: ResetReminder = .none
    @State private var automaticResetEnabled = false
    @State private var isPinned = false
    @State private var isLocked = false
    @State private var milestonesText = "10, 50, 100"

    var body: some View {
        NavigationStack {
            Form {
                if isAdding {
                    Section("Templates") {
                        ForEach(CounterTemplate.allCases) { template in
                            Button { apply(template) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: template.symbol)
                                        .font(.headline.weight(.bold)).foregroundStyle(template.color.color)
                                        .frame(width: 34, height: 34)
                                        .background(template.color.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                                        Text(template.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if templateMatchesCurrent(template) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }

                Section("Counter") {
                    TextField("Name", text: $name)
                    TextField("Folder", text: $group)
                    TextField("Optional goal", text: $goalText).keyboardType(.numberPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section("Favorites & Safety") {
                    Toggle(isOn: $isPinned) { Label("Pin as Favorite", systemImage: "pin.fill") }
                    Toggle(isOn: $isLocked) { Label("Lock Counter", systemImage: "lock.fill") }
                    Text("Locked counters cannot be changed or reset until unlocked.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Step Buttons") {
                    TextField("First step", text: $stepOneText).keyboardType(.numberPad)
                    TextField("Second step", text: $stepTwoText).keyboardType(.numberPad)
                    TextField("Third step", text: $stepThreeText).keyboardType(.numberPad)
                    Text("These become the three positive buttons on the counter card. The −1 button always stays available.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Reset Schedule") {
                    Picker("Schedule", selection: $resetReminder) {
                        ForEach(ResetReminder.allCases) { reminder in
                            Label(reminder.title, systemImage: reminder.systemImage).tag(reminder)
                        }
                    }
                    Toggle("Reset Automatically", isOn: $automaticResetEnabled)
                        .disabled(resetReminder == .none)
                    Text(resetReminder.subtitle).font(.caption).foregroundStyle(.secondary)
                }

                Section("Milestones") {
                    TextField("10, 50, 100", text: $milestonesText)
                        .keyboardType(.numbersAndPunctuation)
                    Text("Enter milestone values separated by commas. Reaching one adds a celebration entry to History.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Style") {
                    NavigationLink {
                        CounterColorSelectionView(selection: $color, title: "Counter Color")
                    } label: {
                        HStack {
                            Text("Counter Color")
                            Spacer()
                            Circle().fill(color.color).frame(width: 24, height: 24)
                            Text(color.title).foregroundStyle(color.color)
                        }
                    }

                    NavigationLink {
                        CounterColorSelectionView(selection: $folderColor, title: "Folder Color")
                    } label: {
                        HStack {
                            Text("Folder Color")
                            Spacer()
                            Image(systemName: "folder.fill").foregroundStyle(folderColor.color)
                            Text(folderColor.title).foregroundStyle(folderColor.color)
                        }
                    }

                    NavigationLink {
                        SymbolSelectionView(selection: $symbol)
                    } label: {
                        HStack {
                            Text("Symbol")
                            Spacer()
                            Image(systemName: symbol).foregroundStyle(color.color)
                            Text(CounterSymbolOption.title(for: symbol)).foregroundStyle(color.color)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populate)
            .onChange(of: resetReminder) { _, newValue in if newValue == .none { automaticResetEnabled = false } }
        }
    }

    private var title: String {
        switch mode { case .add: return "New Counter"; case .edit: return "Edit Counter" }
    }
    private var isAdding: Bool { if case .add = mode { return true }; return false }
    private var stepValues: [Int] {
        TallyCounter.sanitizedStepValues([stepOneText, stepTwoText, stepThreeText].compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) })
    }
    private var milestones: [Int] {
        TallyCounter.sanitizedMilestones(milestonesText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) })
    }

    private func populate() {
        guard case .edit(let counter) = mode else { return }
        name = counter.name
        group = counter.group
        goalText = counter.goal.map(String.init) ?? ""
        symbol = counter.symbol
        color = CounterColor(rawValue: counter.colorName) ?? .blue
        folderColor = CounterColor(rawValue: counter.folderColorName) ?? color
        notes = counter.notes
        resetReminder = counter.resetReminder
        automaticResetEnabled = counter.automaticResetEnabled
        isPinned = counter.isPinned
        isLocked = counter.isLocked
        milestonesText = counter.milestones.map(String.init).joined(separator: ", ")
        applyStepValues(counter.stepValues)
    }

    private func apply(_ template: CounterTemplate) {
        name = template.name
        group = template.group
        goalText = template.goal.map(String.init) ?? ""
        symbol = template.symbol
        color = template.color
        folderColor = template.color
        notes = template.notes
        resetReminder = template.resetReminder
        automaticResetEnabled = false
        applyStepValues(template.stepValues)
    }

    private func applyStepValues(_ values: [Int]) {
        let sanitized = TallyCounter.sanitizedStepValues(values)
        stepOneText = String(sanitized[safe: 0] ?? 1)
        stepTwoText = String(sanitized[safe: 1] ?? 5)
        stepThreeText = String(sanitized[safe: 2] ?? 10)
    }

    private func templateMatchesCurrent(_ template: CounterTemplate) -> Bool {
        name == template.name && group == template.group && goalText == (template.goal.map(String.init) ?? "") &&
        symbol == template.symbol && color == template.color && resetReminder == template.resetReminder &&
        stepValues == TallyCounter.sanitizedStepValues(template.stepValues)
    }

    private func save() {
        let goal = Int(goalText.trimmingCharacters(in: .whitespacesAndNewlines))
        switch mode {
        case .add:
            if let created = store.addCounter(name: name, group: group, goal: goal, symbol: symbol, color: color, notes: notes, stepValues: stepValues, resetReminder: resetReminder),
               var counter = store.counters.first(where: { $0.id == created.id }) {
                counter.isPinned = isPinned
                counter.isLocked = isLocked
                counter.automaticResetEnabled = automaticResetEnabled
                counter.milestones = milestones
                counter.folderColorName = folderColor.rawValue
                store.updateCounter(counter)
                store.updateFolderColor(group: counter.displayGroup, color: folderColor)
            }
        case .edit(var counter):
            counter.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            counter.group = group
            counter.goal = goal
            counter.symbol = symbol
            counter.colorName = color.rawValue
            counter.folderColorName = folderColor.rawValue
            counter.notes = notes
            counter.stepValues = stepValues
            counter.resetReminder = resetReminder
            counter.automaticResetEnabled = automaticResetEnabled
            counter.isPinned = isPinned
            counter.isLocked = isLocked
            counter.milestones = milestones
            store.updateCounter(counter)
            store.updateFolderColor(group: counter.displayGroup, color: folderColor)
        }
        dismiss()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
