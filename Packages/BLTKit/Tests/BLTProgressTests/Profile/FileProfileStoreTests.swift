import BLTProgress
import Foundation
import Testing

struct FileProfileStoreTests {
    private typealias Contract = ProfileStoreContract

    /// Runs `body` with a store whose file lives in a fresh scratch directory.
    private func withStore(_ body: (FileProfileStore, URL) async throws -> Void) async throws {
        try await Contract.withScratchDirectory { directory in
            let fileURL = directory.appendingPathComponent("profile.json")
            try await body(FileProfileStore(fileURL: fileURL), fileURL)
        }
    }

    private func bytes(of fileURL: URL) throws -> Data {
        guard fileURL.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        return try Data(contentsOf: fileURL)
    }

    private func write(_ json: String, to fileURL: URL) throws {
        try Data(json.utf8).write(to: fileURL)
    }

    // MARK: Shared contract

    @Test func newStoreLoadsNil() async throws {
        try await withStore { store, _ in try await Contract.checkNewStoreLoadsNil(store) }
    }

    @Test func roundTrip() async throws {
        try await withStore { store, _ in try await Contract.checkRoundTrip(store) }
    }

    @Test func saveStoresExactlyWhatItIsGiven() async throws {
        try await withStore { store, _ in try await Contract.checkSaveStoresExactlyWhatItIsGiven(store) }
    }

    @Test func overwriteReplacesPreviousName() async throws {
        try await withStore { store, _ in try await Contract.checkOverwriteReplacesPreviousName(store) }
    }

    @Test func eraseClearsAndIsIdempotent() async throws {
        try await withStore { store, _ in try await Contract.checkEraseClearsAndIsIdempotent(store) }
    }

    @Test func saveAfterEraseStartsFresh() async throws {
        try await withStore { store, _ in try await Contract.checkSaveAfterEraseStartsFresh(store) }
    }

    // MARK: File behaviour

    @Test func missingFileLoadsNilAndIsNotCreatedByLoad() async throws {
        try await withStore { store, fileURL in
            let profile = try await store.load()
            #expect(profile == nil)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func dataSurvivesANewStoreOnTheSameFile() async throws {
        try await withStore { store, fileURL in
            try await store.save(UserProfile(name: "zz-name"))

            let reopened = FileProfileStore(fileURL: fileURL)
            let profile = try await reopened.load()
            #expect(profile == UserProfile(name: "zz-name"))
        }
    }

    @Test func saveCreatesMissingParentDirectories() async throws {
        try await Contract.withScratchDirectory { directory in
            let fileURL = directory
                .appendingPathComponent("zz-nested", isDirectory: true)
                .appendingPathComponent("zz-deeper", isDirectory: true)
                .appendingPathComponent("profile.json")
            let store = FileProfileStore(fileURL: fileURL)
            try await store.save(UserProfile(name: "zz"))
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func fileIsJSONWithSchemaVersionOneAndOnlyTheName() async throws {
        try await withStore { store, fileURL in
            try await store.save(UserProfile(name: "zz-name"))

            let data = try bytes(of: fileURL)
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["schemaVersion"] as? Int == 1)
            #expect(object["name"] as? String == "zz-name")
            #expect(Set(object.keys) == ["schemaVersion", "name"])
        }
    }

    // MARK: Corrupt, future and unreadable files

    @Test(arguments: [
        "not json at all",
        "",
        "[]",
        "{}",
        "{\"schemaVersion\":1}",
        "{\"schemaVersion\":1,\"name\":42}",
        "{\"schemaVersion\":\"1\",\"name\":\"zz\"}"
    ])
    func undecodableFileThrowsCorruptAndIsNeverTouched(contents: String) async throws {
        try await withStore { store, fileURL in
            try write(contents, to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProfileStoreError.corrupt) { _ = try await store.load() }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func futureSchemaVersionIsRejectedAndNeverTouched() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"name\":\"zz\",\"extra\":true}", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProfileStoreError.unsupportedSchemaVersion(2)) { _ = try await store.load() }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func futureSchemaIsReportedEvenWhenItsShapeDiffers() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":7,\"displayName\":{}}", to: fileURL)
            await #expect(throws: ProfileStoreError.unsupportedSchemaVersion(7)) { _ = try await store.load() }
        }
    }

    @Test func saveOnCorruptFileThrowsAndDoesNotOverwrite() async throws {
        try await withStore { store, fileURL in
            try write("not json at all", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProfileStoreError.corrupt) {
                try await store.save(UserProfile(name: "zz"))
            }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func saveOnFutureSchemaFileThrowsAndDoesNotOverwrite() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"name\":\"zz\"}", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProfileStoreError.unsupportedSchemaVersion(2)) {
                try await store.save(UserProfile(name: "zz-new"))
            }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func eraseRemovesACorruptFile() async throws {
        try await withStore { store, fileURL in
            try write("not json at all", to: fileURL)
            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            let profile = try await store.load()
            #expect(profile == nil)
        }
    }

    @Test func fileURLThatIsADirectoryIsUnreadable() async throws {
        try await Contract.withScratchDirectory { directory in
            let store = FileProfileStore(fileURL: directory)
            await #expect(throws: ProfileStoreError.unreadable) { _ = try await store.load() }
        }
    }

    // MARK: Erase

    @Test func eraseLeavesNoFile() async throws {
        try await withStore { store, fileURL in
            try await store.save(UserProfile(name: "zz"))
            #expect(FileManager.default.fileExists(atPath: fileURL.path))

            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func eraseNeverDeletesADirectory() async throws {
        try await Contract.withScratchDirectory { directory in
            let sentinel = directory.appendingPathComponent("zz-sentinel.txt")
            try write("zz", to: sentinel)
            let store = FileProfileStore(fileURL: directory)

            await #expect(throws: ProfileStoreError.eraseFailed) { try await store.erase() }
            #expect(FileManager.default.fileExists(atPath: sentinel.path))
        }
    }

    // MARK: Write failure

    @Test func unwritableLocationThrowsAStoreErrorWithoutLeakingDetail() async throws {
        try await Contract.withScratchDirectory { directory in
            let blocker = directory.appendingPathComponent("zz-blocker")
            try write("zz", to: blocker)
            let store = FileProfileStore(fileURL: blocker.appendingPathComponent("profile.json"))

            do throws(ProfileStoreError) {
                try await store.save(UserProfile(name: "zz"))
                Issue.record("expected save to throw")
            } catch {
                let isStoreFailure = error == ProfileStoreError.writeFailed || error == ProfileStoreError.unreadable
                #expect(isStoreFailure)
                let description = String(describing: error)
                #expect(!description.contains(directory.lastPathComponent))
            }
        }
    }
}
