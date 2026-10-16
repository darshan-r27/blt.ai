#if DEBUG
import BLTCatalog
import BLTCore
import SwiftUI

/// Fake `zz` lessons for the cheat sheet previews.
private enum CheatSheetPreviewData {
    static let topicID = ScenarioID(rawValue: "zz-topic")

    static func item(_ number: Int, tokens: [Token], status: ReviewStatus) -> Item {
        Item(
            id: ItemID(rawValue: "zz-item-\(number)"),
            scenarioID: topicID,
            sourcePrompt: "zz prompt \(number)",
            register: .neutral,
            addressee: .any,
            canonical: "zz example \(number)",
            acceptedAnswers: ["zz example \(number)"],
            registerVariant: nil,
            distractors: ["zz wrong"],
            tokens: tokens,
            note: nil,
            reviewStatus: status
        )
    }

    static func zzToken(_ name: String) -> Token {
        Token(word: "zz \(name)", english: "zz gloss \(name)")
    }

    static let finished = Scenario(
        id: topicID,
        title: "zz finished topic",
        subtitle: "zz subtitle",
        romanisationNote: nil,
        items: [
            item(1, tokens: [zzToken("one"), zzToken("two")], status: .reviewed),
            item(2, tokens: [zzToken("three")], status: .unreviewed)
        ],
        language: .tamil
    )

    static let inProgress = Scenario(
        id: ScenarioID(rawValue: "zz-topic-2"),
        title: "zz topic in progress",
        subtitle: "zz subtitle",
        romanisationNote: nil,
        items: [],
        language: .tamil
    )

    @MainActor static func sheet() -> CheatSheetViewModel {
        CheatSheetViewModel(scenario: finished)
    }

    @MainActor static func list() -> CheatSheetListViewModel {
        CheatSheetListViewModel(scenarios: [finished, inProgress], unlockedTopicIDs: [topicID])
    }
}

#Preview("Cheat sheet, light") {
    CheatSheetView(viewModel: CheatSheetPreviewData.sheet(), onClose: {}).preferredColorScheme(.light)
}

#Preview("Cheat sheet, dark") {
    CheatSheetView(viewModel: CheatSheetPreviewData.sheet(), onClose: {}).preferredColorScheme(.dark)
}

#Preview("Cheat sheet, largest accessibility size") {
    CheatSheetView(viewModel: CheatSheetPreviewData.sheet(), onClose: {})
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Cheat sheet list, light") {
    CheatSheetListView(viewModel: CheatSheetPreviewData.list(), onClose: {}).preferredColorScheme(.light)
}

#Preview("Cheat sheet list, dark") {
    CheatSheetListView(viewModel: CheatSheetPreviewData.list(), onClose: {}).preferredColorScheme(.dark)
}

#Preview("Cheat sheet list, largest accessibility size") {
    CheatSheetListView(viewModel: CheatSheetPreviewData.list(), onClose: {})
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
