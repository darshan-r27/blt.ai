import BLTProgress
import Testing

struct ProfileNameValidatorTests {
    private struct Case: Sendable, CustomTestStringConvertible {
        let input: String
        let expected: String
        var testDescription: String { "\(input.debugDescription) -> \(expected.debugDescription)" }
    }

    private static let accepted: [Case] = [
        Case(input: "zz", expected: "zz"),
        Case(input: "Zz Zz", expected: "Zz Zz"),
        Case(input: "  zz  ", expected: "zz"),
        Case(input: "\n\tzz zz \r\n", expected: "zz zz"),
        Case(input: "zz     zz\u{00A0}\u{00A0}zz", expected: "zz zz zz"),
        Case(input: "zz-zz", expected: "zz-zz"),
        Case(input: "zz O'zz", expected: "zz O'zz"),
        Case(input: "zz\u{2019}zz", expected: "zz\u{2019}zz"),
        Case(input: "Zz. Zz", expected: "Zz. Zz"),
        Case(input: "zz 42", expected: "zz 42"),
        // One Tamil letter (U+0B85) stands in for "a non-Latin script"; no real words in code.
        Case(input: "zz\u{0B85}", expected: "zz\u{0B85}"),
        // A combining mark must not count as a separate character.
        Case(input: "zze\u{0301}", expected: "zze\u{0301}")
    ]

    @Test(arguments: accepted)
    private func acceptsAndNormalises(_ testCase: Case) {
        #expect(ProfileNameValidator.validate(testCase.input) == .success(testCase.expected))
    }

    @Test func fortyCharactersIsAccepted() {
        let name = String(repeating: "z", count: 40)
        #expect(ProfileNameValidator.validate(name) == .success(name))
    }

    @Test func fortyOneCharactersIsTooLong() {
        let name = String(repeating: "z", count: 41)
        #expect(ProfileNameValidator.validate(name) == .failure(.tooLong))
    }

    @Test func lengthIsMeasuredAfterNormalisation() {
        let name = "  " + String(repeating: "z", count: 40) + "  "
        #expect(ProfileNameValidator.validate(name) == .success(String(repeating: "z", count: 40)))

        let spaced = "zz" + String(repeating: " ", count: 100) + "zz"
        #expect(ProfileNameValidator.validate(spaced) == .success("zz zz"))
    }

    @Test func lengthCountsCharactersNotScalarsOrBytes() {
        // 40 letters each followed by a combining mark: 80 scalars, 40 Characters.
        let name = String(repeating: "e\u{0301}", count: 40)
        #expect(ProfileNameValidator.validate(name) == .success(name))
        #expect(ProfileNameValidator.validate(name + "e") == .failure(.tooLong))
    }

    @Test(arguments: ["", " ", "   ", "\n", "\t", " \r\n\t ", "\u{00A0}"])
    func emptyAndWhitespaceOnlyAreEmpty(_ input: String) {
        #expect(ProfileNameValidator.validate(input) == .failure(.empty))
    }

    @Test(arguments: [
        "zz\nzz",
        "zz\tzz",
        "zz\r\nzz",
        "zz\u{0000}zz",
        "zz\u{0007}zz",
        "zz\u{001B}zz",
        "zz\u{007F}zz",
        "zz\u{0085}zz",
        "zz\u{2028}zz",
        "zz\u{2029}zz",
        "\u{0000}zz",
        "zz\u{0000}"
    ])
    func controlCharactersAreRejected(_ input: String) {
        #expect(ProfileNameValidator.validate(input) == .failure(.invalidCharacters))
    }

    @Test func zeroWidthJoinerIsAllowed() {
        let name = "zz\u{200D}zz"
        #expect(ProfileNameValidator.validate(name) == .success(name))
    }

    @Test func resultIsIdempotent() throws {
        let first = try ProfileNameValidator.validate("  zz   O'zz-zz  ").get()
        #expect(ProfileNameValidator.validate(first) == .success(first))
    }
}
