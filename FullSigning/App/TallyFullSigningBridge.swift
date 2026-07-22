import Foundation
import ActivityKit
import WidgetKit
#if TALLY_FULL_SIGNING
import CloudKit
#endif

@MainActor
final class TallyFullSigningBridge {
    static let shared = TallyFullSigningBridge()

    private init() {}

    @discardableResult
    func consumePendingExtensionActions(into store: TallyStore) -> UUID? {
        var requestedCounterID: UUID?
        var changedSession = false

        for action in TallyExtensionActionQueue.drain() {
            let counter: TallyCounter?
            if let id = action.counterID {
                counter = store.activeCounters.first(where: { $0.id == id })
            } else {
                counter = store.activeCounters.first(where: \.isPinned) ?? store.activeCounters.first
            }

            switch action.kind {
            case .increment:
                if let counter, !counter.isLocked {
                    store.safeAdjust(counter, by: action.amount)
                    requestedCounterID = counter.id
                }

            case .openCounter:
                requestedCounterID = counter?.id

            case .incrementSessionCounter:
                guard let sessionID = action.sessionID,
                      let session = store.sessions.first(where: { $0.id == sessionID }),
                      let counterID = session.counterID,
                      let linkedCounter = store.activeCounters.first(where: { $0.id == counterID }),
                      !linkedCounter.isLocked else { continue }
                store.safeAdjust(linkedCounter, by: action.amount)
                requestedCounterID = linkedCounter.id
                changedSession = true

            case .toggleSessionPause:
                guard let sessionID = action.sessionID,
                      let session = store.sessions.first(where: { $0.id == sessionID && $0.isActive }) else { continue }
                if session.isPaused {
                    store.resumeSession(session)
                } else {
                    store.pauseSession(session)
                }
                requestedCounterID = session.counterID
                changedSession = true

            case .endSession:
                guard let sessionID = action.sessionID,
                      let session = store.sessions.first(where: { $0.id == sessionID && $0.isActive }) else { continue }
                requestedCounterID = session.counterID
                store.endSession(session)
                changedSession = true
            }
        }

        if requestedCounterID != nil {
            publishWidgetSnapshot(from: store)
        }
        if changedSession {
            Task { await updateLiveActivities(from: store) }
        }
        return requestedCounterID
    }

    func publishWidgetSnapshot(from store: TallyStore) {
        let snapshots = store.activeCounters
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.sortIndex < rhs.sortIndex
            }
            .prefix(12)
            .map { counter in
                TallyWidgetCounterSnapshot(
                    id: counter.id,
                    name: counter.name,
                    value: counter.value,
                    goal: counter.goal,
                    symbol: counter.symbol,
                    colorRaw: counter.colorName,
                    folderName: store.folder(for: counter)?.name ?? "Unfiled",
                    isPinned: counter.isPinned
                )
            }

        _ = TallySharedContainer.writeWidgetSnapshot(
            TallyWidgetSnapshot(generatedAt: Date(), counters: Array(snapshots))
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    func startLiveActivity(for session: TallySession, store: TallyStore) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              session.isActive,
              !Activity<TallySessionActivityAttributes>.activities.contains(where: {
                  $0.attributes.sessionID == session.id
              }) else { return }

        let attributes = TallySessionActivityAttributes(
            sessionID: session.id,
            title: session.title,
            counterName: session.counterName,
            startedAt: session.startedAt,
            goalDuration: session.goalDuration
        )
        let state = activityState(for: session, store: store)
        let content = ActivityContent(state: state, staleDate: nil)
        _ = try? Activity<TallySessionActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func updateLiveActivities(from store: TallyStore) async {
        let existingIDs = Set(
            Activity<TallySessionActivityAttributes>.activities.map { $0.attributes.sessionID }
        )
        for session in store.activeSessions where !existingIDs.contains(session.id) {
            await startLiveActivity(for: session, store: store)
        }

        for activity in Activity<TallySessionActivityAttributes>.activities {
            guard let session = store.sessions.first(where: { $0.id == activity.attributes.sessionID }) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }

            if session.isActive {
                let content = ActivityContent(
                    state: activityState(for: session, store: store),
                    staleDate: nil
                )
                await activity.update(content)
            } else {
                let content = ActivityContent(
                    state: activityState(for: session, store: store),
                    staleDate: Date()
                )
                await activity.end(content, dismissalPolicy: .after(.now + 60))
            }
        }
    }

    func endLiveActivity(sessionID: UUID, store: TallyStore) async {
        for activity in Activity<TallySessionActivityAttributes>.activities where activity.attributes.sessionID == sessionID {
            let session = store.sessions.first(where: { $0.id == sessionID })
            let content = session.map {
                ActivityContent(state: activityState(for: $0, store: store), staleDate: Date())
            }
            await activity.end(content, dismissalPolicy: .after(.now + 60))
        }
    }

    private func activityState(
        for session: TallySession,
        store: TallyStore
    ) -> TallySessionActivityAttributes.ContentState {
        let counterValue = session.counterID.flatMap { id in
            store.counters.first(where: { $0.id == id })?.value
        }
        let now = Date()
        let elapsed = max(0, session.duration)

        return .init(
            elapsedSeconds: Int(elapsed),
            timerStartDate: now.addingTimeInterval(-elapsed),
            timerPauseDate: session.isPaused ? now : nil,
            isPaused: session.isPaused,
            counterValue: counterValue,
            progress: session.progress
        )
    }
}

#if TALLY_FULL_SIGNING
actor TallyCloudSyncCoordinator {
    static let shared = TallyCloudSyncCoordinator()

    private let container = CKContainer(identifier: "iCloud.com.samua.tally")
    private let recordID = CKRecord.ID(recordName: "tally-primary-state")

    func upload(store: TallyStore) async throws {
        let backup = await MainActor.run {
            TallyBackup(
                version: "2.0",
                revision: store.preferences.syncRevision,
                counters: store.counters,
                folders: store.folders,
                history: store.history,
                theme: store.theme,
                sessions: store.sessions,
                preferences: store.preferences
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TallyCloud-\(UUID().uuidString).json")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let database = container.privateCloudDatabase
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "TallyState", recordID: recordID)
        }

        record["schemaVersion"] = "2.0" as NSString
        record["revision"] = NSNumber(value: backup.revision)
        record["exportedAt"] = backup.exportedAt as NSDate
        record["payload"] = CKAsset(fileURL: temporaryURL)
        _ = try await database.save(record)
    }

    func download(into store: TallyStore, replaceExisting: Bool = false) async throws {
        let record = try await container.privateCloudDatabase.record(for: recordID)
        guard let asset = record["payload"] as? CKAsset,
              let sourceURL = asset.fileURL else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TallyCloudImport-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: sourceURL, to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }

        try await MainActor.run {
            try store.importBackup(from: localURL, replaceExisting: replaceExisting)
            store.preferences.lastSyncAt = Date()
        }
    }
}
#endif
