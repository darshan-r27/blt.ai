import BLTProgress
import Foundation
import Testing

/// `FilePracticePreferencesStore` and `InMemoryPracticePreferencesStore`: defaults, round trip, and the
/// file's failure modes.
struct PracticePreferencesStoreTests {
    private typealias Support = PracticeTestSupport

    private func withFileStore(_ body: (FilePracticePreferencesStore, URL) async throws -> Void) async throws {
        try await Support.withScratchDirectory { directory in
            let fileURL = directory.appendingPathComponent("practice-preferences.json")
            try await body(FilePracticePreferencesStore(fileURL: fileURL), fileURL)
        }
    }

    private let changed = PracticePreferences(
        remindersEnabled: false,
        quietHours: QuietHours(startHour: 21, endHour: 7),
        hasAskedForNotifications: true
    )

    @Test func defaultsAreRemindersOnStandardQuietHoursNotAsked() {
        let defaults = PracticePreferences.standard
        #expect(defaults.remindersEnabled)
        #expect(defaults.quietHours == .standard)
        #expect(!defaults.hasAskedForNotifications)
        #expect(defaults.schemaVersion == PracticePreferences.currentSchemaVersion)
    }

    @Test func missingFileLoadsDefaultsAndCreatesNothing() async throws {
        try await withFileStore { store, fileURL in
            let loaded1 = try await store.load()
            #expect(loaded1 == .standard)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func fileStoreRoundTripsAcrossReopen() async throws {
        try await withFileStore { store, fileURL in
            try await store.save(changed)
            let reopened = FilePracticePreferencesStore(fileURL: fileURL)
            let loaded2 = try await reopened.load()
            #expect(loaded2 == changed)
        }
    }

    @Test func fileHasASchemaVersionAndNoDailyGoal() async throws {
        try await withFileStore { store, fileURL in
            try await store.save(changed)
            let text = try #require(String(bytes: try Support.bytes(of: fileURL), encoding: .utf8))
            #expect(text.contains("\"schemaVersion\":1"))
            #expect(!text.lowercased().contains("goal"))
        }
    }

    @Test func inMemoryStoreRoundTrips() async throws {
        let store = InMemoryPracticePreferencesStore()
        let loaded3 = try await store.load()
        #expect(loaded3 == .standard)
        try await store.save(changed)
        let loaded4 = try await store.load()
        #expect(loaded4 == changed)
    }

    @Test func damagedFileIsReportedAndNeverOverwritten() async throws {
        try await withFileStore { store, fileURL in
            let damaged = Data("{ not json".utf8)
            try damaged.write(to: fileURL)

            await #expect(throws: PracticePreferencesError.corrupt) { try await store.load() }
            await #expect(throws: PracticePreferencesError.corrupt) { try await store.save(changed) }
            #expect(try Support.bytes(of: fileURL) == damaged)
        }
    }

    @Test func wrongShapeIsCorruptNotDefaults() async throws {
        try await withFileStore { store, fileURL in
            try Data("{\"schemaVersion\":1,\"remindersEnabled\":\"yes\"}".utf8).write(to: fileURL)
            await #expect(throws: PracticePreferencesError.corrupt) { try await store.load() }
        }
    }

    @Test func newerSchemaIsReportedAndNeverOverwritten() async throws {
        try await withFileStore { store, fileURL in
            let future = Data("{\"schemaVersion\":99,\"somethingNew\":true}".utf8)
            try future.write(to: fileURL)

            await #expect(throws: PracticePreferencesError.unsupportedSchemaVersion(99)) { try await store.load() }
            await #expect(throws: PracticePreferencesError.unsupportedSchemaVersion(99)) {
                try await store.save(changed)
            }
            #expect(try Support.bytes(of: fileURL) == future)
        }
    }
}
