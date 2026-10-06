import BLTCatalog
import Foundation

public struct QuestionBuilder: Sendable {
    public init() {}

    /// Returns `nil` unless there are exactly four options with distinct text (trimmed, case-insensitive).
    public func makeQuestion(for item: Item, using rng: inout some RandomNumberGenerator) -> Question? {
        var options: [AnswerOption] = [AnswerOption(id: 0, text: item.canonical, kind: .canonical)]
        if let variant = item.registerVariant {
            options.append(AnswerOption(id: options.count, text: variant, kind: .registerVariant))
        }
        for distractor in item.distractors {
            options.append(AnswerOption(id: options.count, text: distractor, kind: .distractor))
        }
        guard options.count == 4 else { return nil }
        let normalised = Set(options.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        guard normalised.count == 4 else { return nil }
        return Question(item: item, options: options.shuffled(using: &rng))
    }
}
