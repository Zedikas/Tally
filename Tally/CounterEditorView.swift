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
    @State private var selectedFolderName: String?
    @State private var goalText = ""
    @State private var symbol = "number.square.fill"
    @State private var colorRaw = CounterColor.blue.rawValue
    @State private var folderColorRaw = CounterColor.gray.rawValue
    @State private var counterCustomColor = Color.blue
    @State private var folderCustomColor = Color.blue
    @State private var showingCounterCustomColor = false
    @State private var showingFolderCustomColor = false
    @State private var notes = ""
    @State private var stepOneText = "1"
    @State private var stepTwoText = "5"
    @State private var stepThreeText = "10"
    @State private var resetReminder: ResetReminder = .none
    @State private var automaticResetEnabled = false
    @State private var isPinned = false
    @State private var isLocked = false
    @State private var milestonesText = "10, 50, 100"

    private var counterColor: Color { TallyStoredColor.color(colorRaw) }

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
                    Menu {
                        Button {
                            selectedFolderName = nil
                            folderColorRaw = CounterColor.gray.rawValue
                        } label: {
                            Label("Unfiled", systemImage: selectedFolderName == nil ? "checkmark" : "tray")
                        }
                        if !store.folders.isEmpty { Divider() }
                        ForEach(store.folders) { folder in
                            Button {
                                selectedFolderName = folder.name
                                applyFolderPresets(folder)
                            } label: {
                                Label(folder.name, systemImage: selectedFolderName == folder.name ? "checkmark" : "folder.fill")
                            }
                        }
                    } label: {
                        HStack {
                            Text("Folder").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selectedFolderName == nil ? "tray" : "folder.fill")
                                .foregroundStyle(selectedFolderName.flatMap(store.folder(named:)).map { TallyStoredColor.color($0.colorRaw) } ?? .secondary)
                            Text(selectedFolderName ?? "Unfiled").foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                        }
                    }
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
                    Toggle("Reset Automatically", isOn: $automaticResetEnabled).disabled(resetReminder == .none)
                    Text(resetReminder.subtitle).font(.caption).foregroundStyle(.secondary)
                }

                Section("Milestones") {
                    TextField("10, 50, 100", text: $milestonesText).keyboardType(.numbersAndPunctuation)
                    Text("Enter milestone values separated by commas. Reaching one adds a celebration entry to History.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Style") {
                    StoredColorMenu(title: "Counter Color", systemImage: "circle.fill", rawValue: $colorRaw, customColor: $counterCustomColor, showingCustomPicker: $showingCounterCustomColor)
                    StoredColorMenu(title: "Folder Color", systemImage: "folder.fill", rawValue: $folderColorRaw, customColor: $folderCustomColor, showingCustomPicker: $showingFolderCustomColor)
                        .disabled(selectedFolderName != nil)
                    if selectedFolderName != nil {
                        Text("The selected folder controls its own folder color.").font(.caption).foregroundStyle(.secondary)
                    }
                    Menu {
                        ForEach(CounterSymbolOption.all) { option in
                            Button { symbol = option.symbol } label: {
                                Label(option.title, systemImage: option.symbol)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Symbol").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: symbol).foregroundStyle(counterColor)
                            Text(CounterSymbolOption.title(for: symbol)).foregroundStyle(counterColor)
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(counterColor)
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
            .onAppear { store.ensureFoldersMigrated(); populate() }
            .onChange(of: resetReminder) { _, newValue in if newValue == .none { automaticResetEnabled = false } }
            .sheet(isPresented: $showingCounterCustomColor) {
                CustomStoredColorSheet(title: "Counter Color", rawValue: $colorRaw, color: $counterCustomColor)
            }
            .sheet(isPresented: $showingFolderCustomColor) {
                CustomStoredColorSheet(title: "Folder Color", rawValue: $folderColorRaw, color: $folderCustomColor)
            }
        }
    }

    private var title: String { if case .add = mode { return "New Counter" }; return "Edit Counter" }
    private var isAdding: Bool { if case .add = mode { return true }; return false }
    private var stepValues: [Int] { TallyCounter.sanitizedStepValues([stepOneText, stepTwoText, stepThreeText].compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }) }
    private var milestones: [Int] { TallyCounter.sanitizedMilestones(milestonesText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }) }

    private func populate() {
        guard case .edit(let counter) = mode else { return }
        name = counter.name
        selectedFolderName = store.folder(named: counter.displayGroup)?.name
        goalText = counter.goal.map(String.init) ?? ""
        symbol = counter.symbol
        colorRaw = counter.colorName
        folderColorRaw = selectedFolderName.flatMap(store.folder(named:))?.colorRaw ?? counter.folderColorName
        counterCustomColor = TallyStoredColor.color(colorRaw)
        folderCustomColor = TallyStoredColor.color(folderColorRaw)
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
        selectedFolderName = store.folder(named: template.group)?.name
        goalText = template.goal.map(String.init) ?? ""
        symbol = template.symbol
        colorRaw = template.color.rawValue
        folderColorRaw = selectedFolderName.flatMap(store.folder(named:))?.colorRaw ?? CounterColor.gray.rawValue
        notes = template.notes
        resetReminder = template.resetReminder
        automaticResetEnabled = false
        applyStepValues(template.stepValues)
    }

    private func applyFolderPresets(_ folder: TallyFolder) {
        folderColorRaw = folder.colorRaw
        guard isAdding else { return }
        colorRaw = folder.defaultCounterColorRaw
        symbol = folder.defaultSymbol
        resetReminder = folder.defaultResetReminder
        automaticResetEnabled = folder.defaultAutomaticReset
        applyStepValues(folder.defaultStepValues)
    }

    private func applyStepValues(_ values: [Int]) {
        let sanitized = TallyCounter.sanitizedStepValues(values)
        stepOneText = String(sanitized[safe: 0] ?? 1)
        stepTwoText = String(sanitized[safe: 1] ?? 5)
        stepThreeText = String(sanitized[safe: 2] ?? 10)
    }

    private func templateMatchesCurrent(_ template: CounterTemplate) -> Bool {
        name == template.name && selectedFolderName == store.folder(named: template.group)?.name && goalText == (template.goal.map(String.init) ?? "") && symbol == template.symbol && colorRaw == template.color.rawValue && resetReminder == template.resetReminder && stepValues == TallyCounter.sanitizedStepValues(template.stepValues)
    }

    private func save() {
        let goal = Int(goalText.trimmingCharacters(in: .whitespacesAndNewlines))
        let group = selectedFolderName ?? ""
        let resolvedFolderColor = selectedFolderName.flatMap(store.folder(named:))?.colorRaw ?? folderColorRaw
        let baseColor = CounterColor(rawValue: colorRaw) ?? .blue
        switch mode {
        case .add:
            if let created = store.addCounter(name: name, group: group, goal: goal, symbol: symbol, color: baseColor, notes: notes, stepValues: stepValues, resetReminder: resetReminder),
               var counter = store.counters.first(where: { $0.id == created.id }) {
                counter.colorName = colorRaw
                counter.folderColorName = resolvedFolderColor
                counter.isPinned = isPinned
                counter.isLocked = isLocked
                counter.automaticResetEnabled = automaticResetEnabled
                counter.milestones = milestones
                store.updateCounter(counter)
            }
        case .edit(var counter):
            counter.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            counter.group = group
            counter.goal = goal
            counter.symbol = symbol
            counter.colorName = colorRaw
            counter.folderColorName = resolvedFolderColor
            counter.notes = notes
            counter.stepValues = stepValues
            counter.resetReminder = resetReminder
            counter.automaticResetEnabled = automaticResetEnabled
            counter.isPinned = isPinned
            counter.isLocked = isLocked
            counter.milestones = milestones
            store.updateCounter(counter)
        }
        dismiss()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
