import Foundation
import CoreFoundation
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
    static let expectedWidgetExtensionBundleIdentifier = "com.samua.tally.widgets"
    static let widgetSnapshotKey = "tally.widget.snapshot.v2"
    static let widgetSnapshotFileName = "TallyWidgetSnapshot-v2.json"

    /// Resolve the identifier from the final installed bundle when possible instead of
    /// assuming a re-signing service preserved the build-time identifier verbatim.
    static var widgetExtensionBundleIdentifier: String {
        if Bundle.main.bundleURL.pathExtension == "appex" {
            return Bundle.main.bundleIdentifier ?? expectedWidgetExtensionBundleIdentifier
        }

        if let plugInsURL = Bundle.main.builtInPlugInsURL,
           let urls = try? FileManager.default.contentsOfDirectory(
               at: plugInsURL,
               includingPropertiesForKeys: nil,
               options: [.skipsHiddenFiles]
           ) {
            for url in urls where url.pathExtension == "appex" {
                if url.lastPathComponent == "TallyWidgets.appex",
                   let identifier = Bundle(url: url)?.bundleIdentifier {
                    return identifier
                }
            }
        }

        return expectedWidgetExtensionBundleIdentifier
    }

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
        // 1. Prefer a real file in the shared app-group container.
        if let url = widgetSnapshotURL,
           let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        // 2. Keep the App Group UserDefaults suite as a compatibility fallback.
        if let defaults = UserDefaults(suiteName: appGroup),
           let data = defaults.data(forKey: widgetSnapshotKey),
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        // 3. When this code is running inside TallyWidgets.appex, standard defaults are
        // the widget extension's own preferences domain. The containing app publishes a
        // copy there as an AppDB-friendly fallback that does not depend on App Groups.
        if let data = UserDefaults.standard.data(forKey: widgetSnapshotKey),
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
                // Continue through the additional transports below.
            }
        }

        if let defaults = UserDefaults(suiteName: appGroup) {
            defaults.set(data, forKey: widgetSnapshotKey)
            defaults.synchronize()
            wroteSnapshot = true
        }

        // Apple documents that a containing app can modify preferences for one of its
        // own app extensions. Publish the same snapshot directly into the actual signed
        // widget extension's preferences domain as a fallback for signing methods that
        // preserve the extension but do not provision the App Group entitlement.
        let extensionID = widgetExtensionBundleIdentifier
        CFPreferencesSetAppValue(
            widgetSnapshotKey as CFString,
            data as CFData,
            extensionID as CFString
        )
        if CFPreferencesAppSynchronize(extensionID as CFString) {
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
