import BLTCatalog
import Testing

@testable import BLTFeatures

struct PreviewCatalogTests {
    @Test func everyPreviewStringIsObviouslyFake() {
        for scenario in PreviewCatalog.catalog.scenarios {
            #expect(scenario.id.rawValue.hasPrefix("zz"))
            #expect(scenario.title.hasPrefix("zz"))
            for item in scenario.items {
                let strings = [item.id.rawValue, item.sourcePrompt, item.canonical, item.registerVariant ?? "zz"]
                    + item.acceptedAnswers + item.distractors + item.tokens.flatMap { [$0.tamil, $0.english] }
                for text in strings { #expect(text.hasPrefix("zz")) }
            }
        }
    }

    @Test func previewItemsAreBuildableQuestions() {
        for item in [PreviewCatalog.respectfulItem, PreviewCatalog.neutralItem] {
            let optionCount = 1 + (item.registerVariant == nil ? 0 : 1) + item.distractors.count
            #expect(optionCount == 4)
        }
    }
}
