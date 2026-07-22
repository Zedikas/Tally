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
        // 1. Normal supported path: App Group shared file.
        if let url = widgetSnapshotURL,
           let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        // 2. Normal supported path: App Group shared preferences.
        if let defaults = UserDefaults(suiteName: appGroup),
           let data = defaults.data(forKey: widgetSnapshotKey),
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        // 3. AppDB fallback: explicitly refresh and read the widget extension's own
        // preference domain. Do not rely only on UserDefaults.standard's cached view.
        let extensionID = widgetExtensionBundleIdentifier
        _ = CFPreferencesAppSynchronize(extensionID as CFString)

        if let value = CFPreferencesCopyAppValue(
            widgetSnapshotKey as CFString,
            extensionID as CFString
        ), let data = value as? Data,
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        if let value = CFPreferencesCopyValue(
            widgetSnapshotKey as CFString,
            extensionID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ), let data = value as? Data,
           let snapshot = try? JSONDecoder().decode(TallyWidgetSnapshot.self, from: data) {
            return snapshot
        }

        // 4. Final same-process cache fallback.
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

        // AppDB fallback: Apple permits a containing app to modify preferences for one
        // of its own extensions. Write both the high-level application domain and the
        // exact CurrentUser/AnyHost domain, then force cfprefsd synchronization.
        let extensionID = widgetExtensionBundleIdentifier
        CFPreferencesSetAppValue(
            widgetSnapshotKey as CFString,
            data as CFData,
            extensionID as CFString
        )
        let appSynced = CFPreferencesAppSynchronize(extensionID as CFString)

        CFPreferencesSetValue(
            widgetSnapshotKey as CFString,
            data as CFData,
            extensionID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        let exactSynced = CFPreferencesSynchronize(
            extensionID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )

        if appSynced || exactSynced {
            wroteSnapshot = true
        }

        return wroteSnapshot
    }
}

struct TallySessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var timerStartDate: Date
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
