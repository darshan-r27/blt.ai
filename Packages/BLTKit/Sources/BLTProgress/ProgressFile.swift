import BLTCore
import Foundation

/// The on-disk envelope: `{"schemaVersion": 1, "reviews": [...], "attempts": [...]}`.
///
/// Dates are encoded as numeric seconds since 1970 (`.secondsSince1970`). ISO-8601 strings would drop
/// sub-second precision under Foundation's default formatter, and a store that does not round-trip the
/// values it was given is a bug. Keys are sorted and reviews are ordered by item ID so the file is stable.
///
/// This type is internal; callers only ever see `ProgressSnapshot`.
struct ProgressFile: Codable, Equatable {
    static let currentSchemaVersion = 1

    /// Decoded first, on its own, so a file from a future schema is reported as such even when the rest
    /// of its shape no longer matches this version's.
    private struct Header: Decodable {
        let schemaVersion: Int
    }

    let schemaVersion: Int
    let reviews: [ReviewState]
    let attempts: [AttemptRecord]

    init(snapshot: ProgressSnapshot) {
        schemaVersion = Self.currentSchemaVersion
        reviews = snapshot.reviews.values.sorted { $0.itemID.rawValue < $1.itemID.rawValue }
        attempts = snapshot.attempts
    }

    /// Maps raw file bytes to a snapshot. Every failure becomes a `ProgressStoreError`; nothing in the
    /// error carries file content.
    static func decodeSnapshot(from data: Data) throws(ProgressStoreError) -> ProgressSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let file: ProgressFile
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.schemaVersion == currentSchemaVersion else {
                throw ProgressStoreError.unsupportedSchemaVersion(header.schemaVersion)
            }
            file = try decoder.decode(ProgressFile.self, from: data)
        } catch let error as ProgressStoreError {
            throw error
        } catch {
            throw .corrupt
        }
        var reviews: [ItemID: ReviewState] = [:]
        for review in file.reviews {
            // Two entries for one item cannot come from this store, so the file is not trustworthy.
            guard reviews.updateValue(review, forKey: review.itemID) == nil else { throw .corrupt }
        }
        return ProgressSnapshot(reviews: reviews, attempts: file.attempts)
    }

    func encoded() throws(ProgressStoreError) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(self)
        } catch {
            throw .writeFailed
        }
    }
}

extension ProgressSnapshot {
    /// Appends the attempt and replaces the item's review state, so there is one review per item while
    /// attempts accumulate. Shared by both stores so they cannot drift apart.
    func recording(_ attempt: AttemptRecord, updating review: ReviewState) -> ProgressSnapshot {
        precondition(review.itemID == attempt.itemID, "review and attempt must be for the same item")
        var next = self
        next.attempts.append(attempt)
        next.reviews[review.itemID] = review
        return next
    }
}
