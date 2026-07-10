import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Accent helpers

struct StoredAccentColor {
    static let presetKey = "tally.accentColor"
    static let customKey = "tally.customAccentHex"
    static let customValue = "custom"

    static func resolve(_ raw: String, customHex: String) -> Color {
        if raw == customValue { return Color(hex: customHex) ?? .pink }
        return TallyAccentColor(rawValue: raw)?.color ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    func hexString() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "FF1883" }
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
        #else
        return "FF1883"
        #endif
    }
}

// MARK: - Store features

extension TallyStore {
    func togglePinned(_ counter: TallyCounter) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        counters[index].isPinned.toggle()
        counters[index].updatedAt = Date()
    }

    func toggleLocked(_ counter: TallyCounter) {
        guard let index = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        counters[index].isLocked.toggle()
        counters[index].updatedAt = Date()
    }

    func safeAdjust(_ counter: TallyCounter, by delta: Int) {
        guard let current = counters.first(where: { $0.id == counter.id }), !current.isLocked else { return }
        let before = current.value
        adjust(current, by: delta)
        registerMilestones(counterID: current.id, before: before, after: before + delta)
    }

    func safeReset(_ counter: TallyCounter) {
        guard let current = counters.first(where: { $0.id == counter.id }), !current.isLocked else { return }
        reset(current)
    }

    func safeSetExactValue(_ counter: TallyCounter, to value: Int) {
        guard let current = counters.first(where: { $0.id == counter.id }), !current.isLocked else { return }
        let before = current.value
        setExactValue(current, to: value)
        registerMilestones(counterID: current.id, before: before, after: value)
    }

    func performAutomaticResets(now: Date = Date()) {
        let calendar = Calendar.current
        for index in counters.indices where !counters[index].isArchived && counters[index].automaticResetEnabled && counters[index].resetReminder != .none {
            let counter = counters[index]
            let reference = counter.lastAutomaticResetAt ?? counter.updatedAt
            let shouldReset: Bool
            switch counter.resetReminder {
            case .none:
                shouldReset = false
            case .daily:
                shouldReset = !calendar.isDate(reference, inSameDayAs: now)
            case .weekly:
                shouldReset = calendar.component(.weekOfYear, from: reference) != calendar.component(.weekOfYear, from: now) || calendar.component(.yearForWeekOfYear, from: reference) != calendar.component(.yearForWeekOfYear, from: now)
            case .monthly:
                shouldReset = calendar.component(.month, from: reference) != calendar.component(.month, from: now) || calendar.component(.year, from: reference) != calendar.component(.year, from: now)
            }
            guard shouldReset else { continue }
            let before = counters[index].value
            counters[index].value = 0
            counters[index].lastAutomaticResetAt = now
            counters[index].updatedAt = now
            history.insert(TallyHistoryEntry(counterID: counter.id, counterName: counter.name, action: "Automatic Reset", delta: -before, beforeValue: before, afterValue: 0, date: now), at: 0)
        }
    }

    func updateFolderColor(group: String, color: CounterColor) {
        for index in counters.indices where counters[index].displayGroup == group {
            counters[index].folderColorName = color.rawValue
        }
    }

    func folderColor(for group: String) -> CounterColor {
        guard let raw = counters.first(where: { $0.displayGroup == group })?.folderColorName else { return .gray }
        return CounterColor(rawValue: raw) ?? .gray
    }

    private func registerMilestones(counterID: UUID, before: Int, after: Int) {
        guard let index = counters.firstIndex(where: { $0.id == counterID }) else { return }
        let newlyReached = counters[index].milestones.filter { milestone in
            before < milestone && after >= milestone && !counters[index].reachedMilestones.contains(milestone)
        }
        guard !newlyReached.isEmpty else { return }
        counters[index].reachedMilestones.append(contentsOf: newlyReached)
        counters[index].reachedMilestones = Array(Set(counters[index].reachedMilestones)).sorted()
        for milestone in newlyReached.reversed() {
            history.insert(TallyHistoryEntry(counterID: counterID, counterName: counters[index].name, action: "Milestone \(milestone) 🎉", delta: 0, beforeValue: after, afterValue: after), at: 0)
        }
    }
}

// MARK: - Selection pages

struct CounterColorSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: CounterColor
    let title: String

    var body: some View {
        List {
            ForEach(CounterColor.allCases) { option in
                Button {
                    selection = option
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Circle().fill(option.color).frame(width: 28, height: 28)
                        Text(option.title).font(.headline).foregroundStyle(option.color)
                        Spacer()
                        if selection == option { Image(systemName: "checkmark").font(.headline).foregroundStyle(option.color) }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
    }
}

struct SymbolSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    var body: some View {
        List {
            ForEach(CounterSymbolOption.all) { option in
                Button {
                    selection = option.symbol
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.symbol).font(.title3).frame(width: 32)
                        Text(option.title).font(.headline)
                        Spacer()
                        if selection == option.symbol { Image(systemName: "checkmark") }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Symbol")
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @EnvironmentObject private var store: TallyStore
    @AppStorage(StoredAccentColor.presetKey) private var accentRaw = TallyAccentColor.blue.rawValue
    @AppStorage(StoredAccentColor.customKey) private var customHex = "FF1883"
    @State private var customColor = Color.pink

    private var resolvedColor: Color { StoredAccentColor.resolve(accentRaw, customHex: customHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Picker("Appearance", selection: $store.theme) {
                    Text("Default").tag(TallyTheme.system)
                    Text("Light").tag(TallyTheme.light)
                    Text("Dark").tag(TallyTheme.dark)
                    Text("OLED").tag(TallyTheme.oled)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text("Theme").font(.title2.bold())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(TallyAccentColor.allCases.prefix(6)) { accent in
                        Button {
                            accentRaw = accent.rawValue
                        } label: {
                            VStack(spacing: 12) {
                                Circle().fill(accent.color).frame(width: 48, height: 48)
                                    .overlay(Circle().stroke(.white.opacity(accentRaw == accent.rawValue ? 0.8 : 0), lineWidth: 4))
                                Text(accent.title).foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                ColorPicker(selection: $customColor, supportsOpacity: false) {
                    HStack {
                        Text("Custom Theme Color").font(.headline)
                        Spacer()
                        Circle().fill(customColor).frame(width: 34, height: 34)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onChange(of: customColor) { _, newValue in
                    customHex = newValue.hexString()
                    accentRaw = StoredAccentColor.customValue
                }

                Text("Current accent: #\(accentRaw == StoredAccentColor.customValue ? customHex : resolvedColor.hexString())")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Appearance")
        .onAppear { customColor = Color(hex: customHex) ?? .pink }
    }
}

struct AppIconSettingsView: View {
    @State private var message: String?

    var body: some View {
        List {
            Section("Main") {
                ForEach(TallyIcon.allCases) { icon in
                    Button { setIcon(icon) } label: {
                        HStack(spacing: 16) {
                            iconPreview(icon)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(icon.title).font(.headline).foregroundStyle(.primary)
                                Text(icon.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected(icon) { Image(systemName: "checkmark").font(.title3.bold()) }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("App Icon")
    }

    @ViewBuilder private func iconPreview(_ icon: TallyIcon) -> some View {
        #if canImport(UIKit)
        if let name = icon.bundlePreviewName, let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(icon.tint.gradient).frame(width: 58, height: 58)
                .overlay(Image(systemName: icon.systemImage).font(.title).foregroundStyle(.white))
        }
        #else
        Image(systemName: icon.systemImage).frame(width: 58, height: 58)
        #endif
    }

    private func isSelected(_ icon: TallyIcon) -> Bool {
        #if canImport(UIKit)
        return UIApplication.shared.alternateIconName == icon.iconName || (UIApplication.shared.alternateIconName == nil && icon.iconName == nil)
        #else
        return false
        #endif
    }

    private func setIcon(_ icon: TallyIcon) {
        #if canImport(UIKit)
        guard UIApplication.shared.supportsAlternateIcons else { message = "Alternate icons are not supported by this install."; return }
        UIApplication.shared.setAlternateIconName(icon.iconName) { error in message = error?.localizedDescription ?? "Icon changed to \(icon.title)." }
        #endif
    }
}

// MARK: - Counter details

struct CounterDetailView: View {
    @EnvironmentObject private var store: TallyStore
    let counterID: UUID
    @State private var showingEdit = false
    @State private var exactCounter: TallyCounter?

    private var counter: TallyCounter? { store.counters.first { $0.id == counterID } }
    private var entries: [TallyHistoryEntry] { store.history.filter { $0.counterID == counterID } }
    private var daily: [DailyCounterPoint] {
        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { DailyCounterPoint(date: $0.key, delta: $0.value.map(\.delta).reduce(0,+)) }.sorted { $0.date < $1.date }
    }

    var body: some View {
        Group {
            if let counter {
                ScrollView {
                    VStack(spacing: 18) {
                        detailHeader(counter)
                        quickActions(counter)
                        analytics(counter)
                        if !daily.isEmpty { activityChart }
                        notes(counter)
                        recentHistory
                    }
                    .padding()
                }
                .navigationTitle(counter.name)
                .toolbar {
                    Menu {
                        Button(counter.isPinned ? "Unpin" : "Pin", systemImage: counter.isPinned ? "pin.slash" : "pin") { store.togglePinned(counter) }
                        Button(counter.isLocked ? "Unlock" : "Lock", systemImage: counter.isLocked ? "lock.open" : "lock") { store.toggleLocked(counter) }
                        Button("Edit", systemImage: "pencil") { showingEdit = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                .sheet(isPresented: $showingEdit) { CounterEditorView(mode: .edit(counter)) }
                .sheet(item: $exactCounter) { ExactValueEditor(counter: $0) }
            } else {
                ContentUnavailableView("Counter Unavailable", systemImage: "number.circle")
            }
        }
    }

    private func detailHeader(_ counter: TallyCounter) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: counter.symbol).font(.largeTitle)
                if counter.isPinned { Image(systemName: "pin.fill") }
                if counter.isLocked { Image(systemName: "lock.fill") }
            }
            .foregroundStyle((CounterColor(rawValue: counter.colorName) ?? .blue).color)
            Button { exactCounter = counter } label: {
                Text("\(counter.value)").font(.system(size: 68, weight: .black, design: .rounded)).monospacedDigit()
            }.buttonStyle(.plain)
            if let goal = counter.goal {
                Text("Goal \(counter.value) / \(goal)").foregroundStyle(.secondary)
                ProgressView(value: counter.progress ?? 0).tint((CounterColor(rawValue: counter.colorName) ?? .blue).color)
            }
        }
        .padding(22).frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func quickActions(_ counter: TallyCounter) -> some View {
        HStack {
            Button("−1") { store.safeAdjust(counter, by: -1) }
            ForEach(counter.stepValues, id: \.self) { step in Button("+\(step)") { store.safeAdjust(counter, by: step) } }
        }
        .buttonStyle(.borderedProminent).disabled(counter.isLocked)
    }

    private func analytics(_ counter: TallyCounter) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            DetailMetric(title: "Changes", value: "\(entries.count)")
            DetailMetric(title: "Net", value: signed(entries.map(\.delta).reduce(0,+)))
            DetailMetric(title: "Best Day", value: signed(daily.map(\.delta).max() ?? 0))
            DetailMetric(title: "Milestones", value: "\(counter.reachedMilestones.count)/\(counter.milestones.count)")
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading) {
            Text("Activity").font(.headline)
            Chart(daily.suffix(30)) { point in
                BarMark(x: .value("Day", point.date, unit: .day), y: .value("Change", point.delta))
            }.frame(height: 180)
        }
        .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func notes(_ counter: TallyCounter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            Text(counter.notes.isEmpty ? "No notes" : counter.notes).foregroundStyle(counter.notes.isEmpty ? .secondary : .primary)
            if !counter.milestones.isEmpty { Text("Milestones: \(counter.milestones.map(String.init).joined(separator: ", "))").font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent History").font(.headline)
            ForEach(entries.prefix(10)) { entry in
                HStack { Text(entry.action); Spacer(); Text(entry.date, style: .relative).foregroundStyle(.secondary) }
                Divider()
            }
        }
        .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
}

struct DailyCounterPoint: Identifiable { let id = UUID(); let date: Date; let delta: Int }

struct DetailMetric: View {
    let title: String; let value: String
    var body: some View {
        VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.bold()).monospacedDigit() }
            .frame(maxWidth: .infinity, alignment: .leading).padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension TallyIcon {
    var bundlePreviewName: String? {
        switch id {
        case "primary": return nil
        case "neon": return "TallyIconNeonDark"
        case "glass": return "TallyIconGlass"
        case "pearl": return "TallyIconPearl"
        case "amber": return "TallyIconAmber"
        case "green": return "TallyIconTechGreen"
        case "purple": return "TallyIconCosmicPurple"
        case "synth": return "TallyIconSynthwave"
        default: return nil
        }
    }
}
