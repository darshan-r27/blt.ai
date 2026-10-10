import BLTProgress
import Foundation
import Testing

/// Checks every `ExamResultStore` must pass, shared by the file-backed and in-memory tests so the two
/// cannot drift apart. Not a suite of its own: the store test files call these.
enum ExamResultStoreContract {
    /// A unique directory under Application Support (not the temporary directory, which the guard script
    /// bans), removed when `body` finishes.
    static func withScratchDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("zz-BLTExamTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }

    /// A fake attempt. `day` keeps dates whole seconds apart so each attempt is distinguishable.
    static func attempt(
        day: Int = 0,
        correct: Int = 80,
        total: Int = 100,
        passed: Bool = true,
        levels: [ExamLevelScore] = [ExamLevelScore(level: 1, correct: 8, total: 10)]
    ) -> ExamAttempt {
        ExamAttempt(
            date: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400),
            correct: correct,
            total: total,
            passed: passed,
            levels: levels
        )
    }

    static func checkNewStoreLoadsEmpty(_ store: any ExamResultStore) async throws {
        #expect(try await store.load().isEmpty)
        #expect(try await store.bestAttempt() == nil)
        #expect(try await store.hasPassed() == false)
    }

    static func checkAppendRoundTrips(_ store: any ExamResultStore) async throws {
        let first = attempt(
            day: 1,
            correct: 60,
            total: 100,
            passed: false,
            levels: [
                ExamLevelScore(level: 1, correct: 5, total: 10),
                ExamLevelScore(level: nil, correct: 55, total: 90)
            ]
        )
        try await store.append(first)
        #expect(try await store.load() == [first])
    }

    static func checkAttemptsComeBackOldestFirst(_ store: any ExamResultStore) async throws {
        let attempts = (0..<5).map { attempt(day: $0, correct: 50 + $0) }
        for item in attempts {
            try await store.append(item)
        }
        #expect(try await store.load() == attempts)
    }

    static func checkKeepsOnlyTheLastTwentyAttempts(_ store: any ExamResultStore) async throws {
        #expect(ExamHistory.maxAttempts == 20)
        let attempts = (0..<25).map { attempt(day: $0, correct: $0) }
        for item in attempts {
            try await store.append(item)
        }
        let loaded = try await store.load()
        #expect(loaded.count == 20)
        #expect(loaded == Array(attempts.suffix(20)))
    }

    static func checkExactlyTwentyAreAllKept(_ store: any ExamResultStore) async throws {
        let attempts = (0..<20).map { attempt(day: $0, correct: $0) }
        for item in attempts {
            try await store.append(item)
        }
        #expect(try await store.load() == attempts)
    }

    static func checkBestAttemptIsTheHighestShareAndLatestWinsTies(_ store: any ExamResultStore) async throws {
        let low = attempt(day: 1, correct: 60, total: 100, passed: false)
        let high = attempt(day: 2, correct: 90, total: 100, passed: true)
        let tied = attempt(day: 3, correct: 45, total: 50, passed: true)
        let lower = attempt(day: 4, correct: 70, total: 100, passed: false)
        for item in [low, high, tied, lower] {
            try await store.append(item)
        }
        // 90/100 and 45/50 are the same share, and the later one wins.
        #expect(try await store.bestAttempt() == tied)
    }

    static func checkHasPassedIsTrueOnceAnyAttemptPassed(_ store: any ExamResultStore) async throws {
        try await store.append(attempt(day: 1, correct: 60, passed: false))
        #expect(try await store.hasPassed() == false)
        try await store.append(attempt(day: 2, correct: 80, passed: true))
        try await store.append(attempt(day: 3, correct: 50, passed: false))
        #expect(try await store.hasPassed() == true)
    }

    static func checkEraseClearsAndIsIdempotent(_ store: any ExamResultStore) async throws {
        try await store.erase()
        try await store.append(attempt())
        try await store.erase()
        try await store.erase()
        #expect(try await store.load().isEmpty)
        #expect(try await store.hasPassed() == false)
    }

    static func checkAppendAfterEraseStartsFresh(_ store: any ExamResultStore) async throws {
        try await store.append(attempt(day: 1))
        try await store.erase()
        let fresh = attempt(day: 2, correct: 40, passed: false)
        try await store.append(fresh)
        #expect(try await store.load() == [fresh])
    }
}
