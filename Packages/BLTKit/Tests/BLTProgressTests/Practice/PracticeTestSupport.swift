import BLTProgress
import Foundation

/// Builders shared by the practice and streak tests. Dates are fixed instants in March 2026 so no test
/// reads the clock.
enum PracticeTestSupport {
    static func calendar(_ identifier: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
        return calendar
    }

    static let utc = calendar()

    /// A moment on a given date in `calendar` (default UTC); month defaults to March 2026.
    static func date(
        _ day: Int, _ hour: Int, _ minute: Int = 0,
        month: Int = 3, year: Int = 2026, in calendar: Calendar = utc
    ) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    /// A session of ten answers finishing at the given moment on a March 2026 date (UTC).
    static func at(_ day: Int, _ hour: Int, _ minute: Int = 0, answered: Int = 10) -> PracticeSession {
        session(date(day, hour, minute), answered: answered)
    }

    static func bytes(of fileURL: URL) throws -> Data {
        guard fileURL.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        return try Data(contentsOf: fileURL)
    }

    static func hours(_ count: Double) -> TimeInterval { count * 3600 }

    static func session(_ finishedAt: Date, answered: Int = 10) -> PracticeSession {
        PracticeSession(finishedAt: finishedAt, answered: answered)
    }

    /// One session per day for `count` days at 09:00 UTC starting on 1 March.
    static func dailyLog(days count: Int) -> PracticeLog {
        PracticeLog(sessions: (0..<count).map { session(date(1 + $0, 9)) })
    }

    static func summary(
        _ log: PracticeLog, now: Date, in calendar: Calendar = utc, goal: Int = 2
    ) -> StreakSummary {
        StreakCalculator(dailyGoal: goal).summary(for: log, now: now, calendar: calendar)
    }

    /// A unique directory under Application Support (not the temporary directory, which the guard script
    /// bans), removed when `body` finishes.
    static func withScratchDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = base.appendingPathComponent("zz-BLTPracticeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }
}
