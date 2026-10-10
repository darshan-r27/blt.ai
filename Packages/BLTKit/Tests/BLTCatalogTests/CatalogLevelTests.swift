import BLTCatalog
import BLTCore
import Foundation
import Testing

/// The optional lesson-level `level` object (DECISIONS 039).
struct CatalogLevelTests {
    private typealias Fix = CatalogFormatFixtures

    @Test func fileWithoutLevelIsValidAndHasNoLevel() throws {
        let catalog = try Fix.load([Fix.scenario(items: [Fix.item(id: "zz-1")])])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.first?.level == nil)
    }

    @Test func validLevelIsCarriedOntoTheScenario() throws {
        let level = Fix.level(number: 3, title: "zz level", position: 7)
        let raw = Fix.scenario(level: level, items: [Fix.item(id: "zz-1")])
        let catalog = try Fix.load([raw])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.first?.level == Level(number: 3, title: "zz level", position: 7))
    }

    @Test func levelNumberBelowOneIsReportedAndTheFileDropped() throws {
        let raw = Fix.scenario(level: Fix.level(number: 0), items: [Fix.item(id: "zz-1")])
        let catalog = try Fix.load([raw])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues.map(\.rule) == [.invalidLevelNumber])
    }

    @Test func levelPositionBelowOneIsReported() throws {
        let raw = Fix.scenario(level: Fix.level(position: 0), items: [Fix.item(id: "zz-1")])
        let catalog = try Fix.load([raw])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues.map(\.rule) == [.invalidLevelPosition])
    }

    @Test func levelWithAnEmptyOrOverLongOrNativeScriptTitleIsReported() throws {
        let cases: [(String, ContentIssue.Rule)] = [
            ("   ", .emptyField(.level)),
            (String(repeating: "a", count: 501), .fieldTooLong(.level)),
            ("zz\u{0B85}", .nativeScriptInField(.level))
        ]
        for (title, rule) in cases {
            let raw = Fix.scenario(level: Fix.level(title: title), items: [Fix.item(id: "zz-1")])
            let catalog = try Fix.load([raw])
            #expect(catalog.scenarios.isEmpty)
            #expect(catalog.issues.map(\.rule) == [rule])
        }
    }

    @Test func levelMissingAKeyOrOfTheWrongTypeIsReported() throws {
        var noPosition = Fix.level()
        noPosition.removeValue(forKey: "position")
        var wrongType = Fix.level()
        wrongType["number"] = "zz"
        let cases: [(Any, ContentIssue.Rule)] = [
            (noPosition, .missingField(.level)),
            (wrongType, .unknownValue(.level)),
            ("zz not an object", .unknownValue(.level))
        ]
        for (level, rule) in cases {
            var raw = Fix.scenario(items: [Fix.item(id: "zz-1")])
            raw["level"] = level
            let catalog = try Fix.load([raw])
            #expect(catalog.scenarios.isEmpty)
            #expect(catalog.issues.map(\.rule) == [rule])
        }
    }

    @Test func sameLevelNumberWithADifferentTitleDropsTheLaterFile() throws {
        let first = Fix.scenario(id: "zz-first", level: Fix.level(title: "zz one"), items: [Fix.item(id: "zz-1")])
        let second = Fix.scenario(
            id: "zz-second", level: Fix.level(title: "zz other", position: 2), items: [Fix.item(id: "zz-2")]
        )
        let catalog = try Fix.load([first, second])
        #expect(catalog.scenarios.map(\.id.rawValue) == ["zz-first"])
        #expect(catalog.issues == [
            ContentIssue(
                fileIndex: 1, scenarioID: ScenarioID(rawValue: "zz-second"), itemID: nil, rule: .levelTitleMismatch
            )
        ])
    }

    @Test func sameLevelNumberWithTheSameTitleAfterTrimmingIsAccepted() throws {
        let first = Fix.scenario(id: "zz-first", level: Fix.level(title: "zz one"), items: [Fix.item(id: "zz-1")])
        let second = Fix.scenario(
            id: "zz-second", level: Fix.level(title: "  zz one ", position: 2), items: [Fix.item(id: "zz-2")]
        )
        let catalog = try Fix.load([first, second])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.compactMap(\.level?.title) == ["zz one", "zz one"])
    }

    @Test func levelTitleComparisonIsCaseSensitive() throws {
        let first = Fix.scenario(id: "zz-first", level: Fix.level(title: "zz one"), items: [Fix.item(id: "zz-1")])
        let second = Fix.scenario(
            id: "zz-second", level: Fix.level(title: "ZZ ONE", position: 2), items: [Fix.item(id: "zz-2")]
        )
        let catalog = try Fix.load([first, second])
        #expect(catalog.issues.map(\.rule) == [.levelTitleMismatch])
    }

    @Test func differentLevelNumbersMayHaveDifferentTitles() throws {
        let first = Fix.scenario(
            id: "zz-first", level: Fix.level(number: 1, title: "zz one"), items: [Fix.item(id: "zz-1")]
        )
        let second = Fix.scenario(
            id: "zz-second", level: Fix.level(number: 2, title: "zz two"), items: [Fix.item(id: "zz-2")]
        )
        #expect(try Fix.load([first, second]).issues.isEmpty)
    }
}
