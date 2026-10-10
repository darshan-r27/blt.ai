import BLTCore
import BLTProgress
import Foundation
import Testing

/// Schema 1 and schema 2 files and the learning language (DECISIONS 043). The file-format checks that
/// are not about the language stay in `FileProfileStoreTests`.
struct FileProfileSchemaTests {
    private func withStore(_ body: (FileProfileStore, URL) async throws -> Void) async throws {
        try await ProfileStoreContract.withScratchDirectory { directory in
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

    // MARK: Schema 1 (written before the language existed)

    @Test func schemaOneFileLoadsWithNoLanguageAndTheSameName() async throws {
        try await withStore { store, fileURL in
            let json = "{\"name\":\"zz-name\",\"schemaVersion\":1}"
            try write(json, to: fileURL)

            let profile = try await store.load()
            #expect(profile?.name == "zz-name")
            #expect(profile?.learningLanguage == nil)
            let after = try bytes(of: fileURL)
            #expect(after == Data(json.utf8))
        }
    }

    @Test func schemaOneFileIsRewrittenAsSchemaTwoOnSave() async throws {
        try await withStore { store, fileURL in
            try write("{\"name\":\"zz-name\",\"schemaVersion\":1}", to: fileURL)
            let loaded = try #require(try await store.load())

            try await store.save(loaded.withLearningLanguage(.tamil))
            let data = try bytes(of: fileURL)
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["schemaVersion"] as? Int == 2)
            #expect(object["learningLanguage"] as? String == "tamil")
            let reloaded = try await store.load()
            #expect(reloaded == UserProfile(name: "zz-name", learningLanguage: .tamil))
        }
    }

    @Test func schemaOneFileIgnoresALanguageKey() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":1,\"name\":\"zz\",\"learningLanguage\":\"tamil\"}", to: fileURL)
            let profile = try await store.load()
            #expect(profile == UserProfile(name: "zz"))
        }
    }

    @Test(arguments: [
        ("tamil", CourseLanguage.tamil),
        ("telugu", CourseLanguage.telugu)
    ])
    func schemaTwoFileLoadsItsLanguage(raw: String, expected: CourseLanguage) async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"name\":\"zz\",\"learningLanguage\":\"\(raw)\"}", to: fileURL)
            let profile = try await store.load()
            #expect(profile == UserProfile(name: "zz", learningLanguage: expected))
        }
    }

    @Test func schemaTwoFileWithoutALanguageLoadsWithNone() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"name\":\"zz\"}", to: fileURL)
            let profile = try await store.load()
            #expect(profile == UserProfile(name: "zz"))
        }
    }

    @Test(arguments: [
        "\"zz\"",
        "\"\"",
        "\"Tamil\"",
        "\"tamil \"",
        "\"hindi\"",
        "7",
        "true",
        "[]",
        "{}"
    ])
    func unknownOrMalformedLanguageIsADamagedProfileAndIsNeverTouched(value: String) async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"name\":\"zz\",\"learningLanguage\":\(value)}", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProfileStoreError.corrupt) { _ = try await store.load() }
            await #expect(throws: ProfileStoreError.corrupt) {
                try await store.save(UserProfile(name: "zz-new", learningLanguage: .tamil))
            }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }
}
