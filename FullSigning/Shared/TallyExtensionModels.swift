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

    static func readWidgetSnapshot() -> TallyWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: widgetSnapshotKey),
              let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func writeWidgetSnapshot(_ snapshot: TallyWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: widgetSnapshotKey)
    }
}

struct TallySessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
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
