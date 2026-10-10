import BLTCore
import Testing
@testable import BLTFeatures

@MainActor
struct HomeEmptyStateTests {
    @Test func withNoLanguageTheGeneralLineStays() {
        let copy = HomeViewModel.emptyStateCopy(for: nil)
        #expect(copy.title == "No scenarios")
        #expect(copy.description == "This copy of the app has no lesson content to show.")
    }

    @Test(arguments: CourseLanguage.allCases)
    func aNamedLanguageIsNamedInTheTitleAndTheDescription(_ language: CourseLanguage) {
        let copy = HomeViewModel.emptyStateCopy(for: language)
        #expect(copy.title.contains(language.displayName))
        #expect(copy.description.contains(language.displayName))
    }

    @Test func theTwoLanguagesGetDifferentLines() {
        #expect(HomeViewModel.emptyStateCopy(for: .tamil).title != HomeViewModel.emptyStateCopy(for: .telugu).title)
    }
}
