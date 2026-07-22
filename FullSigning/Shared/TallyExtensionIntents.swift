import AppIntents
import Foundation
import CoreFoundation

struct TallyPendingExtensionAction: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case increment
        case openCounter
        case incrementSessionCounter
        case toggleSessionPause
        case endSession
    }

    var id: UUID = UUID()
    var kind: Kind
    var counterID: UUID?
    var sessionID: UUID?
    var amount: Int
    var createdAt: Date = Date()

    init(
        kind: Kind,
        counterID: UUID? = nil,
        sessionID: UUID? = nil,
        amount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.kind = kind
        self.counterID = counterID
        self.sessionID = sessionID
        self.amount = amount
        self.createdAt = createdAt
    }
}

enum TallyExtensionActionQueue {
    private static let key = "tally.extension.pending-actions.v2"

    static func append(_ action: TallyPendingExtensionAction) {
        var actions = readFromCurrentProcessDefaults()

        if let defaults = UserDefaults(suiteName: TallySharedContainer.appGroup) {
            actions.append(contentsOf: read(from: defaults))
        }

        actions = deduplicated(actions + [action])
        actions = Array(actions.suffix(50))
        guard let data = try? JSONEncoder().encode(actions) else { return }

        if let defaults = UserDefaults(suiteName: TallySharedContainer.appGroup) {
            defaults.set(data, forKey: key)
            defaults.synchronize()
        }

        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.synchronize()
    }

    static func drain() -> [TallyPendingExtensionAction] {
        var actions: [TallyPendingExtensionAction] = []

        if let defaults = UserDefaults(suiteName: TallySharedContainer.appGroup) {
            actions.append(contentsOf: read(from: defaults))
            defaults.removeObject(forKey: key)
            defaults.synchronize()
        }

        actions.append(contentsOf: readFromCurrentProcessDefaults())
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.synchronize()

        let extensionID = TallySharedContainer.widgetExtensionBundleIdentifier
        if let value = CFPreferencesCopyAppValue(key as CFString, extensionID as CFString),
           let data = value as? Data,
           let queued = try? JSONDecoder().decode([TallyPendingExtensionAction].self, from: data) {
            actions.append(contentsOf: queued)
        }
        CFPreferencesSetAppValue(key as CFString, nil, extensionID as CFString)
        _ = CFPreferencesAppSynchronize(extensionID as CFString)

        return deduplicated(actions).sorted { $0.createdAt < $1.createdAt }
    }

    private static func readFromCurrentProcessDefaults() -> [TallyPendingExtensionAction] {
        read(from: UserDefaults.standard)
    }

    private static func read(from defaults: UserDefaults) -> [TallyPendingExtensionAction] {
        guard let data = defaults.data(forKey: key),
              let actions = try? JSONDecoder().decode([TallyPendingExtensionAction].self, from: data) else {
            return []
        }
        return actions
    }

    private static func deduplicated(_ actions: [TallyPendingExtensionAction]) -> [TallyPendingExtensionAction] {
        var seen = Set<UUID>()
        return actions.filter { seen.insert($0.id).inserted }
    }
}

struct TallyExtensionIncrementIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Tally Counter"
    static var description = IntentDescription("Increment a Tally counter from a widget or Control Center.")
    static var openAppWhenRun = true

    @Parameter(title: "Counter ID", default: "")
    var counterID: String

    @Parameter(title: "Amount", default: 1)
    var amount: Int

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

    @Parameter(title: "Counter ID", default: "")
    var counterID: String

    init() {}

    init(counterID: String) {
        self.counterID = counterID
    }

    func perform() async throws -> some IntentResult {
        TallyExtensionActionQueue.append(
            TallyPendingExtensionAction(
                kind: .openCounter,
                counterID: UUID(uuidString: counterID)
            )
        )
        return .result()
    }
}

struct TallyExtensionSessionActionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Control Tally Session"
    static var description = IntentDescription("Pause, resume, finish, or increment the counter linked to a Live Activity.")

    // LiveActivityIntent already tells iOS to execute this intent in Tally's app process.
    // Keeping this false prevents a Lock Screen button from foregrounding the UI.
    static var openAppWhenRun = false

    @Parameter(title: "Session ID", default: "")
    var sessionID: String

    @Parameter(title: "Action", default: "toggle")
    var command: String

    @Parameter(title: "Amount", default: 1)
    var amount: Int

    init() {}

    init(sessionID: String, command: String, amount: Int = 1) {
        self.sessionID = sessionID
        self.command = command
        self.amount = amount
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = UUID(uuidString: sessionID) else {
            return .result(dialog: "That Tally session is no longer available.")
        }

        #if TALLY_WIDGET_EXTENSION
        // This copy exists only so the widget target can compile the shared intent type.
        // LiveActivityIntent execution is routed by iOS to the containing app process,
        // where the implementation below updates persistent Tally state directly.
        let kind: TallyPendingExtensionAction.Kind
        switch command {
        case "end": kind = .endSession
        case "increment": kind = .incrementSessionCounter
        default: kind = .toggleSessionPause
        }
        TallyExtensionActionQueue.append(
            TallyPendingExtensionAction(
                kind: kind,
                sessionID: id,
                amount: min(max(amount, -9999), 9999)
            )
        )
        return .result(dialog: "Updating the Tally session…")
        #else
        let message = await Task { @MainActor in
            let store = TallyStore()

            guard let session = store.sessions.first(where: { $0.id == id }) else {
                if command == "end" {
                    await TallyFullSigningBridge.shared.endLiveActivity(sessionID: id, store: store)
                    return "Finished the Live Activity."
                }
                return "That Tally session is no longer available."
            }

            switch command {
            case "end":
                store.endSession(session)
                await TallyFullSigningBridge.shared.endLiveActivity(sessionID: id, store: store)
                return "Finished \(session.title)."

            case "increment":
                guard let counterID = session.counterID,
                      let counter = store.activeCounters.first(where: { $0.id == counterID }),
                      !counter.isLocked else {
                    return "This session does not have an adjustable counter."
                }
                store.safeAdjust(counter, by: min(max(amount, -9999), 9999))
                await TallyFullSigningBridge.shared.updateLiveActivities(from: store)
                TallyFullSigningBridge.shared.publishWidgetSnapshot(from: store)
                return "Updated \(counter.name)."

            default:
                if session.isPaused {
                    store.resumeSession(session)
                } else {
                    store.pauseSession(session)
                }
                await TallyFullSigningBridge.shared.updateLiveActivities(from: store)
                return session.isPaused ? "Paused \(session.title)." : "Updated \(session.title)."
            }
        }.value

        return .result(dialog: IntentDialog(stringLiteral: message))
        #endif
    }
}
