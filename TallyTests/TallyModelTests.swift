import XCTest
@testable import Tally

final class TallyModelTests: XCTestCase {
    func testLegacyCounterDecodesWithSafeTallyTwoDefaults() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "name": "Legacy Counter",
          "value": 7,
          "goal": 10,
          "group": "Legacy Folder",
          "symbol": "number.square.fill",
          "colorName": "blue",
          "notes": "",
          "createdAt": 0,
          "updatedAt": 0
        }
        """.data(using: .utf8)!

        let counter = try JSONDecoder().decode(TallyCounter.self, from: json)

        XCTAssertEqual(counter.id, id)
        XCTAssertEqual(counter.group, "Legacy Folder")
        XCTAssertNil(counter.folderID)
        XCTAssertEqual(counter.stepValues, [1, 5, 10])
        XCTAssertEqual(counter.resetHour, 0)
        XCTAssertEqual(counter.resetWeekday, 2)
        XCTAssertFalse(counter.carryExcessOnReset)
        XCTAssertFalse(counter.resetNotificationEnabled)
    }

    func testBackupDecodesWithoutFoldersOrPreferences() throws {
        let counter = TallyCounter(
            name: "Imported",
            value: 3,
            goal: nil,
            group: "Old Folder",
            symbol: "number.square.fill",
            colorName: CounterColor.blue.rawValue,
            notes: ""
        )
        let oldBackup = TallyBackup(
            version: "1.7",
            counters: [counter],
            folders: [],
            history: [],
            theme: .dark,
            sessions: []
        )
        let data = try JSONEncoder().encode(oldBackup)
        let decoded = try JSONDecoder().decode(TallyBackup.self, from: data)

        XCTAssertEqual(decoded.version, "1.7")
        XCTAssertEqual(decoded.counters.count, 1)
        XCTAssertTrue(decoded.folders.isEmpty)
        XCTAssertEqual(decoded.preferences.signingMode, "AppDB-safe")
    }

    func testStepSanitizationKeepsThreeUniquePositiveValues() {
        XCTAssertEqual(TallyCounter.sanitizedStepValues([0, 1, 1, 5, 10, 20]), [1, 5, 10])
        XCTAssertEqual(TallyCounter.sanitizedStepValues([]), [1, 5, 10])
        XCTAssertEqual(TallyCounter.sanitizedStepValues([-1, 20_000]), [9_999])
    }

    func testPinnedSortingDoesNotChangeFolderRelationship() {
        let folderID = UUID()
        let pinned = TallyCounter(
            name: "Pinned",
            value: 1,
            goal: nil,
            group: "Folder",
            folderID: folderID,
            sortIndex: 5,
            symbol: "pin.fill",
            colorName: CounterColor.blue.rawValue,
            notes: "",
            isPinned: true
        )
        let normal = TallyCounter(
            name: "Normal",
            value: 1,
            goal: nil,
            group: "Folder",
            folderID: folderID,
            sortIndex: 0,
            symbol: "number.square.fill",
            colorName: CounterColor.blue.rawValue,
            notes: ""
        )

        let ordered = [normal, pinned].sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.sortIndex < rhs.sortIndex
        }

        XCTAssertEqual(ordered.first?.id, pinned.id)
        XCTAssertEqual(ordered.first?.folderID, folderID)
        XCTAssertEqual(ordered.last?.folderID, folderID)
    }

    func testPausedSessionStopsAdvancingDuration() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let paused = Date(timeIntervalSinceReferenceDate: 160)
        let session = TallySession(
            title: "Focus",
            counterID: nil,
            counterName: "Standalone",
            startedAt: start,
            startValue: 0,
            notes: "",
            pausedAt: paused,
            accumulatedPausedDuration: 10,
            goalDuration: 120
        )

        XCTAssertTrue(session.isPaused)
        XCTAssertEqual(session.duration, 50, accuracy: 0.001)
        XCTAssertEqual(session.progress ?? 0, 50.0 / 120.0, accuracy: 0.001)
    }
}
