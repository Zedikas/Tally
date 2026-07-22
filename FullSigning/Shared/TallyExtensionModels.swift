import Foundation
import ActivityKit

struct TallyWidgetCounterSnapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var value: Int
    var goal: Int?
    var symbol: String
    var colorRaw: String
    var folderName: String
    var isPinned: Bool
}

struct TallyWidgetSnapshot: Codable, Hashable {
    var generatedAt: Date
    var counters: [TallyWidgetCounterSnapshot]

    static let empty = TallyWidgetSnapshot(generatedAt: Date(), counters: [])
}

enum TallySharedContainer {
    static let appGroup = "group.com.samua.tally"
    static let widgetSnapshotKey = "tally.widget.snapshot.v2"
    static let widgetSnapshotFileName = "TallyWidgetSnapshot-v2.json"

    /// A real app-group container is the strongest runtime proof that the final
    /// provisioning profile preserved the App Groups entitlement after AppDB re-signing.
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static var hasSharedContainerAccess: Bool {
        sharedContainerURL != nil
    }

    private static var widgetSnapshotURL: URL? {
        sharedContainerURL?.appendingPathComponent(widgetSnapshotFileName, isDirectory: false)
    }

    static func readWidgetSnapshot() -> TallyWidgetSnapshot {
        // Prefer a real file in the shared app-group container. This is more explicit
        // and reliable across the host app/widget process boundary than relying only
        // on UserDefaults suite propagation.
        if let url = widgetSnapshotURL,
           let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        // Keep the suite-backed snapshot as a compatibility fallback.
        if let defaults = UserDefaults(suiteName: appGroup),
           let data = defaults.data(forKey: widgetSnapshotKey),
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        return .empty
    }

    @discardableResult
    static func writeWidgetSnapshot(_ snapshot: TallyWidgetSnapshot) -> Bool {
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        var wroteSnapshot = false

        if let url = widgetSnapshotURL {
            do {
                try data.write(to: url, options: [.atomic])
                wroteSnapshot = true
            } catch {
                // UserDefaults below remains a fallback if the shared file write fails.
            }
        }

        if let defaults = UserDefaults(suiteName: appGroup) {
            defaults.set(data, forKey: widgetSnapshotKey)
            // synchronize() is intentionally used here as a best-effort cross-process
            // flush before WidgetCenter asks the extension for a new timeline.
            defaults.synchronize()
            wroteSnapshot = true
        }

        return wroteSnapshot
    }
}

struct TallySessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Retained as a stable snapshot/fallback value.
        var elapsedSeconds: Int
        /// Effective start date after subtracting accumulated paused time. SwiftUI can
        /// use this to render a system-updating timer without ActivityKit pushes every second.
        var timerStartDate: Date
        /// Non-nil while paused so SwiftUI freezes the timer at the correct instant.
        var timerPauseDate: Date?
        var isPaused: Bool
        var counterValue: Int?
        var progress: Double?
    }

    var sessionID: UUID
    var title: String
    var counterName: String
    var startedAt: Date
    var goalDuration: TimeInterval?
}
