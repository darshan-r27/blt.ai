import BLTDesign
import SwiftUI
import Testing

struct CompletionBarTests {
    @Test func labelIsAPlainPercentString() {
        #expect(CompletionBar.label(forPercent: 35) == "35%")
        #expect(CompletionBar.label(forPercent: 0) == "0%")
        #expect(CompletionBar.label(forPercent: 100) == "100%")
    }

    @Test func accessibilityValueReadsAsWords() {
        #expect(CompletionBar.accessibilityValue(forPercent: 35) == "35 percent complete")
        #expect(CompletionBar.accessibilityValue(forPercent: 0) == "0 percent complete")
        #expect(CompletionBar.accessibilityValue(forPercent: 100) == "100 percent complete")
    }

    @Test func outOfRangePercentsAreClamped() {
        #expect(CompletionBar.clamped(-5) == 0)
        #expect(CompletionBar.clamped(140) == 100)
        #expect(CompletionBar.label(forPercent: 140) == "100%")
        #expect(CompletionBar.accessibilityValue(forPercent: -1) == "0 percent complete")
    }

    @Test(arguments: Palette.Scheme.allCases)
    func fillStandsOutFromTrackAndCard(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        #expect(palette.accent.contrastRatio(with: palette.accentTint) >= 3, "fill vs track in \(scheme)")
        #expect(palette.accent.contrastRatio(with: palette.surface) >= 3, "fill vs card in \(scheme)")
    }

    @Test(arguments: Palette.Scheme.allCases)
    func percentLabelMeetsWCAGAAOnTheCard(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        let ratio = palette.textPrimary.contrastRatio(with: palette.surface)
        #expect(ratio >= 4.5, "label on card in \(scheme) is \(ratio)")
    }

    @MainActor
    @Test func isAViewTakingAWholePercent() {
        let view = CompletionBar(percent: 35)
        #expect(String(describing: type(of: view)).contains("CompletionBar"))
    }
}
