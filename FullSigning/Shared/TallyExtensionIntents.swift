import AppIntents
import Foundation

struct TallyPendingExtensionAction: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case increment
        case openCounter
    }

    var id: UUID = UUID()
    var kind: Kind
    var counterID: UUID?
    var amount: Int
    var createdAt: Date = Date()
}

enum TallyExtensionActionQueue {
    private static let key = "tally.extension.pending-actions.v2"

    static func append(_ action: TallyPendingExtensionAction) {
        guard let defaults = UserDefaults(suiteName: TallySharedContainer.appGroup) else { return }
        var actions = read(from: defaults)
        actions.append(action)
        actions = Array(actions.suffix(50))
        if let data = try? JSONEncoder().encode(actions) {
            defaults.set(data, forKey: key)
        }
    }

    static func drain() -> [TallyPendingExtensionAction] {
        guard let defaults = UserDefaults(suiteName: TallySharedContainer.appGroup) else { return [] }
        let actions = read(from: defaults)
        defaults.removeObject(forKey: key)
        return actions
    }

    private static func read(from defaults: UserDefaults) -> [TallyPendingExtensionAction] {
        guard let data = defaults.data(forKey: key),
              let actions = try? JSONDecoder().decode([TallyPendingExtensionAction].self, from: data) else {
            return []
        }
        return actions
    }
}

struct TallyExtensionIncrementIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Tally Counter"
    static var description = IntentDescription("Increment a Tally counter from a widget or Control Center.")
    static var openAppWhenRun = true

    @Parameter(title: "Counter ID")
    var counterID: String = ""

    @Parameter(title: "Amount")
    var amount: Int = 1

    init() {}

    init(counterID: String, amount: Int) {
        self.counterID = counterID
        self.amount = amount
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = UUID(uuidString: counterID)
        let safeAmount = min(max(amount, -9999), 9999)
        TallyExtensionActionQueue.append(
            TallyPendingExtensionAction(kind: .increment, counterID: id, amount: safeAmount)
        )
        return .result(dialog: "Updating Tally…")
    }
}

struct TallyExtensionOpenCounterIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tally Counter"
    static var openAppWhenRun = true

    @Parameter(title: "Counter ID")
    var counterID: String = ""

    init() {}

    init(counterID: String) {
        self.counterID = counterID
    }

    func perform() async throws -> some IntentResult {
        TallyExtensionActionQueue.append(
            TallyPendingExtensionAction(kind: .openCounter, counterID: UUID(uuidString: counterID), amount: 0)
        )
        return .result()
    }
}
