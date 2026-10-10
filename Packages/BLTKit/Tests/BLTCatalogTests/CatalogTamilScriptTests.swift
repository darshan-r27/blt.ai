import BLTCatalog
import BLTCore
import Foundation
import Testing

/// The optional item-level `tamilScript` field (DECISIONS 040).
struct CatalogTamilScriptTests {
    private typealias Fix = CatalogFormatFixtures

    private func loaded(tamilScript: Any?) throws -> Catalog {
        var item = Fix.item(id: "zz-1")
        if let tamilScript { item["tamilScript"] = tamilScript }
        return try Fix.load([Fix.scenario(items: [item, Fix.item(id: "zz-good")])])
    }

    @Test func missingTamilScriptIsValid() throws {
        let catalog = try loaded(tamilScript: nil)
        #expect(catalog.issues.isEmpty)
        #expect(catalog.item(ItemID(rawValue: "zz-1"))?.tamilScript == nil)
    }

    @Test func validTamilScriptIsKeptAndTamilIsStillBannedElsewhere() throws {
        let catalog = try loaded(tamilScript: Fix.fakeTamil)
        #expect(catalog.issues.isEmpty)
        #expect(catalog.item(ItemID(rawValue: "zz-1"))?.tamilScript == Fix.fakeTamil)

        var item = Fix.item(id: "zz-2")
        item["note"] = Fix.fakeTamil
        let rejected = try Fix.load([Fix.scenario(items: [item, Fix.item(id: "zz-good")])])
        #expect(rejected.issues.map(\.rule) == [.tamilScriptInField(.note)])
    }

    @Test func tamilScriptMayContainSpacesDigitsAndPunctuation() throws {
        let catalog = try loaded(tamilScript: "\(Fix.fakeTamil) \(Fix.fakeTamil)?, 1")
        #expect(catalog.issues.isEmpty)
    }

    @Test func tamilScriptWithLatinLettersIsReportedAndTheItemDropped() throws {
        for text in ["\(Fix.fakeTamil) zz", "\(Fix.fakeTamil)A", "z\(Fix.fakeTamil)"] {
            let catalog = try loaded(tamilScript: text)
            #expect(catalog.issues.map(\.rule) == [.latinLettersInTamilScript])
            #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
        }
    }

    @Test func emptyTamilScriptIsReported() throws {
        for text in ["", "   "] {
            let catalog = try loaded(tamilScript: text)
            #expect(catalog.issues.map(\.rule) == [.emptyField(.tamilScript)])
        }
    }

    @Test func tamilScriptWithoutATamilCodePointIsReported() throws {
        // Just outside the block on both sides, and plain digits.
        for text in ["\u{0B7F}", "\u{0C00}", "123"] {
            let catalog = try loaded(tamilScript: text)
            #expect(catalog.issues.map(\.rule) == [.tamilScriptMissingTamil])
        }
    }

    @Test func tamilScriptBlockBoundariesAreAccepted() throws {
        for text in ["\u{0B80}", "\u{0BFF}"] {
            #expect(try loaded(tamilScript: text).issues.isEmpty)
        }
    }

    @Test func tamilScriptOverTheLengthLimitOrOfTheWrongTypeIsReported() throws {
        let tooLong = String(repeating: "\u{0B85}", count: 501)
        #expect(try loaded(tamilScript: tooLong).issues.map(\.rule) == [.fieldTooLong(.tamilScript)])
        #expect(try loaded(tamilScript: 5).issues.map(\.rule) == [.unknownValue(.tamilScript)])
        let atLimit = String(repeating: "\u{0B85}", count: 500)
        #expect(try loaded(tamilScript: atLimit).issues.isEmpty)
    }
}
