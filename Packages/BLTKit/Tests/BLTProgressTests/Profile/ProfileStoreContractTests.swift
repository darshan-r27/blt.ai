import BLTProgress
import Foundation
import Testing

/// Checks every `ProfileStore` must pass, shared by the file-backed and in-memory tests so the two cannot
/// drift apart. Not a suite of its own: the store test files call these.
enum ProfileStoreContract {
    /// A unique directory under Application Support (not the temporary directory, which the guard script
    /// bans), removed when `body` finishes.
    static func withScratchDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("zz-BLTProfileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }

    static func checkNewStoreLoadsNil(_ store: any ProfileStore) async throws {
        let profile = try await store.load()
        #expect(profile == nil)
    }

    static func checkRoundTrip(_ store: any ProfileStore) async throws {
        let profile = UserProfile(name: "zz O'zz-zz\u{0B85}")
        try await store.save(profile)
        let loaded = try await store.load()
        #expect(loaded == profile)
    }

    static func checkSaveStoresExactlyWhatItIsGiven(_ store: any ProfileStore) async throws {
        let raw = UserProfile(name: "  zz   zz  ")
        try await store.save(raw)
        let loaded = try await store.load()
        #expect(loaded == raw)
    }

    static func checkOverwriteReplacesPreviousName(_ store: any ProfileStore) async throws {
        try await store.save(UserProfile(name: "zz-one"))
        try await store.save(UserProfile(name: "zz-two"))
        let loaded = try await store.load()
        #expect(loaded == UserProfile(name: "zz-two"))
    }

    static func checkEraseClearsAndIsIdempotent(_ store: any ProfileStore) async throws {
        try await store.erase()
        try await store.save(UserProfile(name: "zz"))
        try await store.erase()
        try await store.erase()
        let loaded = try await store.load()
        #expect(loaded == nil)
    }

    static func checkSaveAfterEraseStartsFresh(_ store: any ProfileStore) async throws {
        try await store.save(UserProfile(name: "zz-one"))
        try await store.erase()
        try await store.save(UserProfile(name: "zz-two"))
        let loaded = try await store.load()
        #expect(loaded == UserProfile(name: "zz-two"))
    }
}
