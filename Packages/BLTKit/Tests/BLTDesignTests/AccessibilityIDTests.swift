import BLTDesign
import Testing

struct AccessibilityIDTests {
    @Test func twoWayCourseIDsAreDistinctAndNamespaced() {
        let ids = [
            AccessibilityID.languageContinue,
            AccessibilityID.homeLanguage,
            AccessibilityID.homeContinueLesson,
            AccessibilityID.homeOtherLessons,
            AccessibilityID.settingsLanguage,
            AccessibilityID.settingsLanguageConfirm,
            AccessibilityID.settingsLanguageCancel,
            AccessibilityID.languageOption("zz"),
            AccessibilityID.homeLevel(1),
            AccessibilityID.settingsLanguageOption("zz")
        ]
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.contains(".") })
    }

    @Test func parameterisedIDsIncludeTheirArgument() {
        #expect(AccessibilityID.languageOption("zz") == "language.option.zz")
        #expect(AccessibilityID.homeLevel(3) == "home.level.3")
        #expect(AccessibilityID.settingsLanguageOption("zz") == "settings.language.option.zz")
        #expect(AccessibilityID.homeLevel(1) != AccessibilityID.homeLevel(2))
    }
}
