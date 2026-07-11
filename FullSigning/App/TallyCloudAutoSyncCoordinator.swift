import CloudKit
import Foundation

actor TallyCloudAutoSyncCoordinator {
    static let shared = TallyCloudAutoSyncCoordinator()

    private let container = CKContainer(identifier: "iCloud.com.samua.tally")
    private let recordID = CKRecord.ID(recordName: "tally-primary-state")
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    func synchronize(store: TallyStore) async throws {
        let local = await MainActor.run { makeLocalBackup(store: store) }
        let database = container.privateCloudDatabase

        let remoteRecord: CKRecord
        do {
            remoteRecord = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            try await upload(local, database: database)
            await MainActor.run {
                store.preferences.lastSyncAt = Date()
                store.preferences.syncRevision = local.revision
            }
            return
        }

        guard let remoteAsset = remoteRecord["payload"] as? CKAsset,
              let remoteURL = remoteAsset.fileURL else {
            try await upload(local, database: database)
            return
        }

        let remoteData = try Data(contentsOf: remoteURL)
        let remote = try decoder.decode(TallyBackup.self, from: remoteData)
        let merged = merge(local: local, remote: remote)

        await MainActor.run {
            store.registerUndoSnapshot(label: "Cloud Sync")
            store.folders = merged.folders
            store.counters = merged.counters.map(store.normalizedCounter)
            store.history = merged.history
            store.sessions = merged.sessions
            store.theme = merged.theme
            var preferences = merged.preferences
            preferences.lastSyncAt = Date()
            preferences.syncRevision = merged.revision
            store.preferences = preferences
            store.ensureFoldersMigrated()
        }

        try await upload(merged, database: database)
    }

    private func makeLocalBackup(store: TallyStore) -> TallyBackup {
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

    private func merge(local: TallyBackup, remote: TallyBackup) -> TallyBackup {
        let lastSync = local.preferences.lastSyncAt ?? .distantPast
        let localNewestChange = local.counters.map(\.updatedAt).max() ?? .distantPast
        let localChangedSinceSync = localNewestChange > lastSync
        let remoteChangedSinceSync = remote.exportedAt > lastSync

        var folderMap = Dictionary(uniqueKeysWithValues: remote.folders.map { ($0.id, $0) })
        for folder in local.folders {
            // Folder records do not yet carry an updatedAt field, so the active device wins
            // for matching IDs while remote-only folders are retained.
            folderMap[folder.id] = folder
        }
        let folders = folderMap.values.sorted { $0.sortIndex < $1.sortIndex }

        var counterMap = Dictionary(uniqueKeysWithValues: remote.counters.map { ($0.id, $0) })
        for counter in local.counters {
            if let remoteCounter = counterMap[counter.id] {
                counterMap[counter.id] = counter.updatedAt >= remoteCounter.updatedAt ? counter : remoteCounter
            } else {
                counterMap[counter.id] = counter
            }
        }
        let counters = counterMap.values.sorted { lhs, rhs in
            if lhs.folderID == rhs.folderID { return lhs.sortIndex < rhs.sortIndex }
            return lhs.updatedAt > rhs.updatedAt
        }

        var historyMap = Dictionary(uniqueKeysWithValues: remote.history.map { ($0.id, $0) })
        for entry in local.history { historyMap[entry.id] = entry }
        let history = historyMap.values.sorted { $0.date > $1.date }

        var sessionMap = Dictionary(uniqueKeysWithValues: remote.sessions.map { ($0.id, $0) })
        for session in local.sessions {
            if let remoteSession = sessionMap[session.id] {
                sessionMap[session.id] = sessionSortDate(session) >= sessionSortDate(remoteSession) ? session : remoteSession
            } else {
                sessionMap[session.id] = session
            }
        }
        let sessions = sessionMap.values.sorted { $0.startedAt > $1.startedAt }

        let remoteWinsAppearance = remoteChangedSinceSync && !localChangedSinceSync
        let theme = remoteWinsAppearance ? remote.theme : local.theme
        var preferences = remoteWinsAppearance ? remote.preferences : local.preferences
        preferences.deviceID = local.preferences.deviceID
        preferences.signingMode = local.preferences.signingMode
        preferences.syncRevision = max(local.revision, remote.revision) + 1
        preferences.lastSyncAt = Date()

        return TallyBackup(
            version: "2.0",
            exportedAt: Date(),
            revision: preferences.syncRevision,
            counters: counters,
            folders: folders,
            history: history,
            theme: theme,
            sessions: sessions,
            preferences: preferences
        )
    }

    private func upload(_ backup: TallyBackup, database: CKDatabase) async throws {
        let data = try encoder.encode(backup)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TallyCloudAuto-\(UUID().uuidString).json")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

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

    private func sessionSortDate(_ session: TallySession) -> Date {
        session.endedAt ?? session.pausedAt ?? session.startedAt
    }
}
