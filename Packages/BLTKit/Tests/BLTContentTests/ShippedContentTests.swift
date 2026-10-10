import BLTCatalog
import BLTCore
import Foundation
import Testing

/// Conformance of the content that ships in `content/<language>/*.json`, loaded through the real
/// `ContentLoader`, one course at a time (DECISIONS 044). A course folder that does not exist yet is
/// allowed; once it exists every rule here applies to it.
struct ShippedContentTests {
    private let expectedItemsPerLesson = 20

    /// The five lessons written before `script` existed (DECISIONS 044). They are the only lessons allowed to
    /// have items without a `script`. Delete this constant, and the exemption in `everyNewStyleItemHasAScript`,
    /// when those five lessons are backfilled with their native-script spellings.
    private let grandfatheredWithoutScript: Set<String> = [
        "ta-l01-u01", "ta-l01-u02", "ta-l01-u03", "ta-l01-u04", "ta-l01-u05"
    ]

    private func load(_ language: CourseLanguage) throws -> (files: [URL], catalog: Catalog) {
        let files = try ShippedContentFiles.files(for: language)
        let catalog = ContentLoader(limits: .default).load(files: files, expectedLanguage: language)
        return (files, catalog)
    }

    private func describe(_ issue: ContentIssue, files: [URL]) -> String {
        let name = files.indices.contains(issue.fileIndex) ? files[issue.fileIndex].lastPathComponent : "?"
        let scenario = issue.scenarioID?.rawValue ?? "-"
        let item = issue.itemID?.rawValue ?? "-"
        return "file \(issue.fileIndex) (\(name)), scenario \(scenario), item \(item), rule \(issue.rule)"
    }

    private func rawObject(_ file: URL) throws -> [String: Any] {
        precondition(file.isFileURL)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        return try #require(object as? [String: Any])
    }

    /// Counts the `reviewStatus` strings written in the raw JSON, independent of the loader.
    private func rawReviewStatusCounts(files: [URL]) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for file in files where file.isFileURL {
            precondition(file.isFileURL)
            let items = try #require(try rawObject(file)["items"] as? [[String: Any]])
            for item in items {
                let status = item["reviewStatus"] as? String
                let key = status == "unreviewed" || status == "reviewed" ? (status ?? "") : "other"
                counts[key, default: 0] += 1
            }
        }
        return counts
    }

    @Test func shippedContentLoadsWithoutIssuesInEachLanguage() throws {
        for language in CourseLanguage.allCases {
            let (files, catalog) = try load(language)
            let lines = catalog.issues.map { describe($0, files: files) }
            #expect(
                catalog.issues.isEmpty,
                Comment(rawValue: "\(language.rawValue) content issues (fix in content/, not in tests):\n"
                    + lines.joined(separator: "\n"))
            )
        }
    }

    @Test func tamilHasAtLeastFiveLessonFiles() throws {
        let (files, catalog) = try load(.tamil)
        #expect(files.count >= 5)
        #expect(catalog.scenarios.count == files.count)
    }

    @Test func everyFileDeclaresTheLanguageOfItsFolder() throws {
        for language in CourseLanguage.allCases {
            for file in try ShippedContentFiles.files(for: language) {
                let declared = try rawObject(file)["language"] as? String
                #expect(declared == language.rawValue, "\(file.lastPathComponent) says \(declared ?? "nothing")")
            }
        }
    }

    @Test func everyLessonHasTwentyItemsAndATitle() throws {
        for language in CourseLanguage.allCases {
            let (files, catalog) = try load(language)
            #expect(catalog.scenarios.count == files.count)
            for scenario in catalog.scenarios {
                #expect(
                    scenario.items.count == expectedItemsPerLesson,
                    "lesson \(scenario.id.rawValue) has \(scenario.items.count) items"
                )
                let title = scenario.title.trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(!title.isEmpty, "lesson \(scenario.id.rawValue) has an empty title")
            }
        }
    }

    @Test func lessonAndItemIDsFollowTheNamingScheme() throws {
        for language in CourseLanguage.allCases {
            let (files, catalog) = try load(language)
            let lessonPattern = try Regex("\(language.idPrefix)-l[0-9]{2}-u[0-9]{2}")
            for scenario in catalog.scenarios {
                let lesson = scenario.id.rawValue
                #expect(lesson.wholeMatch(of: lessonPattern) != nil, "lesson id \(lesson) is not <prefix>-lNN-uNN")
                #expect(
                    files.contains { $0.lastPathComponent.hasPrefix(lesson + "-") },
                    "no file in content/\(language.rawValue)/ is named for lesson \(lesson)"
                )
                let itemPattern = try Regex("\(lesson)-i[0-9]{2}")
                for item in scenario.items {
                    #expect(
                        item.id.rawValue.wholeMatch(of: itemPattern) != nil,
                        "item id \(item.id.rawValue) is not \(lesson)-iNN"
                    )
                }
            }
        }
    }

    @Test func levelNumbersHaveNoGapsAndOneTitleEach() throws {
        for language in CourseLanguage.allCases {
            let catalog = try load(language).catalog
            var titles: [Int: Set<String>] = [:]
            for scenario in catalog.scenarios {
                let level = try #require(scenario.level, "lesson \(scenario.id.rawValue) has no level")
                titles[level.number, default: []].insert(level.title)
            }
            guard let highest = titles.keys.max() else { continue }
            let numbers = titles.keys.sorted()
            #expect(Set(numbers) == Set(1...highest), "\(language.rawValue) levels have a gap: \(numbers)")
            for (number, names) in titles {
                #expect(names.count == 1, "\(language.rawValue) level \(number) has titles \(names.sorted())")
            }
        }
    }

    @Test func everyNewStyleItemHasAScript() throws {
        for language in CourseLanguage.allCases {
            let catalog = try load(language).catalog
            for scenario in catalog.scenarios where !grandfatheredWithoutScript.contains(scenario.id.rawValue) {
                for item in scenario.items {
                    #expect(item.script != nil, "item \(item.id.rawValue) has no script")
                }
            }
        }
    }

    @Test func everyItemHasTokens() throws {
        for language in CourseLanguage.allCases {
            for scenario in try load(language).catalog.scenarios {
                for item in scenario.items {
                    #expect(!item.tokens.isEmpty, "item \(item.id.rawValue) has no tokens")
                }
            }
        }
    }

    @Test func itemIDsAreUniqueAcrossTheCatalog() throws {
        for language in CourseLanguage.allCases {
            let catalog = try load(language).catalog
            let ids = catalog.scenarios.flatMap { $0.items.map(\.id.rawValue) }
            #expect(Set(ids).count == ids.count)
            #expect(catalog.allItemIDs.count == ids.count)
        }
    }

    /// The type only allows two statuses, so check the loader did not default anything: the counts of each
    /// status in the raw JSON must match the counts in the loaded catalog, and no raw value may be anything else.
    @Test func reviewStatusIsNeverSilentlyDefaulted() throws {
        for language in CourseLanguage.allCases {
            let (files, catalog) = try load(language)
            let loaded = catalog.scenarios.flatMap(\.items)
            let raw = try rawReviewStatusCounts(files: files)

            let other = raw["other"] ?? 0
            #expect(other == 0, "\(language.rawValue): \(other) items with a missing or unknown reviewStatus")
            #expect(loaded.filter { $0.reviewStatus == .unreviewed }.count == (raw["unreviewed"] ?? 0))
            #expect(loaded.filter { $0.reviewStatus == .reviewed }.count == (raw["reviewed"] ?? 0))
            #expect(loaded.count == (raw["unreviewed"] ?? 0) + (raw["reviewed"] ?? 0))
        }
    }
}
