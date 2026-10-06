import BLTCore
import Foundation

/// Turns decoded raw scenarios into the frozen domain types, enforcing every rule in docs/MVP_PLAN.md
/// section 2. Invalid items are skipped and reported; valid siblings survive. Nothing is defaulted:
/// a missing or unrecognised value is an issue, never a guess.
struct ContentValidator: Sendable {
    let limits: ContentLoader.Limits

    typealias Validation = (scenario: Scenario?, issues: [ContentIssue])

    /// Validates one scenario file. `scenarioIDs` and `itemIDs` carry ids already accepted from earlier
    /// files, so a repeated id is rejected here and the earlier file wins.
    func validate(
        _ raw: RawScenario,
        fileIndex: Int,
        scenarioIDs: inout Set<ScenarioID>,
        itemIDs: inout Set<ItemID>
    ) -> Validation {
        var header = Checker(limits: limits, fileIndex: fileIndex, malformed: raw.malformed)
        let rawID = header.string(raw.scenarioId, .scenarioId)
        header.scenarioID = rawID.map { ScenarioID(rawValue: $0) }
        let title = header.string(raw.title, .title)
        let subtitle = header.string(raw.subtitle, .subtitle)
        let romanisationNote = header.string(raw.romanisationNote, .note, required: false)
        guard header.issues.isEmpty, let scenarioID = header.scenarioID, let title, let subtitle else {
            return (nil, header.issues)
        }
        guard scenarioIDs.insert(scenarioID).inserted else {
            return (nil, [header.issue(.duplicateScenarioID)])
        }
        guard let rawItems = raw.items, !rawItems.isEmpty else {
            return (nil, [header.issue(.emptyScenario)])
        }
        guard rawItems.count <= limits.maxItemsPerFile else {
            return (nil, [header.issue(.tooManyItems)])
        }

        var items: [Item] = []
        var issues: [ContentIssue] = []
        for rawItem in rawItems {
            let result = validateItem(rawItem, scenarioID: scenarioID, fileIndex: fileIndex)
            issues.append(contentsOf: result.issues)
            guard let item = result.item else { continue }
            if itemIDs.insert(item.id).inserted {
                items.append(item)
            } else {
                issues.append(ContentIssue(
                    fileIndex: fileIndex, scenarioID: scenarioID, itemID: item.id, rule: .duplicateItemID
                ))
            }
        }
        guard !items.isEmpty else {
            issues.append(header.issue(.emptyScenario))
            return (nil, issues)
        }
        let scenario = Scenario(
            id: scenarioID, title: title, subtitle: subtitle, romanisationNote: romanisationNote, items: items
        )
        return (scenario, issues)
    }

    private func validateItem(
        _ raw: RawItem,
        scenarioID: ScenarioID,
        fileIndex: Int
    ) -> (item: Item?, issues: [ContentIssue]) {
        var checker = Checker(limits: limits, fileIndex: fileIndex, malformed: raw.malformed)
        checker.scenarioID = scenarioID
        guard !raw.isNotAnObject else { return (nil, [checker.issue(.missingField(.id))]) }

        let id = checker.string(raw.id, .id)
        checker.itemID = id.map { ItemID(rawValue: $0) }
        let sourcePrompt = checker.string(raw.sourcePrompt, .sourcePrompt)
        let register: Register? = checker.enumValue(raw.register, .register)
        let addressee: Addressee? = checker.enumValue(raw.addressee, .addressee)
        let canonical = checker.string(raw.canonical, .canonical)
        let acceptedAnswers = checker.strings(raw.acceptedAnswers, .acceptedAnswers)
        let registerVariant = checker.string(raw.registerVariant, .registerVariant, required: false)
        let distractors = checker.strings(raw.distractors, .distractors)
        let tokens = checker.tokens(raw.tokens)
        let note = checker.string(raw.note, .note, required: false)
        let reviewStatus: ReviewStatus? = checker.enumValue(raw.reviewStatus, .reviewStatus)

        guard checker.issues.isEmpty,
              let itemID = checker.itemID, let sourcePrompt, let register, let addressee, let canonical,
              let acceptedAnswers, let distractors, let tokens, let reviewStatus
        else { return (nil, checker.issues) }

        let item = Item(
            id: itemID,
            scenarioID: scenarioID,
            sourcePrompt: sourcePrompt,
            register: register,
            addressee: addressee,
            canonical: canonical,
            acceptedAnswers: acceptedAnswers,
            registerVariant: registerVariant,
            distractors: distractors,
            tokens: tokens,
            note: note,
            reviewStatus: reviewStatus
        )
        let rules = Self.relationRules(for: item)
        guard rules.isEmpty else { return (nil, rules.map { checker.issue($0) }) }
        return (item, [])
    }

    /// Cross-field rules, checked on a fully built item so every value is known to be present and clean.
    private static func relationRules(for item: Item) -> [ContentIssue.Rule] {
        var rules: [ContentIssue.Rule] = []
        let accepted = Set(item.acceptedAnswers.map(normalised))
        let others = (item.registerVariant.map { [$0] } ?? []) + item.distractors
        let options = [item.canonical] + others

        if !(3...6).contains(item.acceptedAnswers.count) { rules.append(.wrongAcceptedCount) }
        if !accepted.contains(normalised(item.canonical)) { rules.append(.canonicalNotAccepted) }
        if others.contains(where: { accepted.contains(normalised($0)) }) { rules.append(.otherOptionAccepted) }
        if Set(options.map(normalised)).count != options.count { rules.append(.duplicateOptionText) }
        if (item.register == .neutral) != (item.registerVariant == nil) { rules.append(.registerVariantMismatch) }
        if item.distractors.count != (item.registerVariant == nil ? 3 : 2) { rules.append(.wrongDistractorCount) }
        let tokenMissing = item.tokens.contains {
            item.canonical.range(of: normalised($0.tamil), options: .caseInsensitive) == nil
        }
        if tokenMissing { rules.append(.tokenNotInCanonical) }
        return rules
    }

    private static func normalised(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension ContentValidator {
    /// Collects issues for one scenario header or item while its fields are checked.
    private struct Checker {
        let limits: ContentLoader.Limits
        let fileIndex: Int
        let malformed: Set<ContentIssue.Field>
        var scenarioID: ScenarioID?
        var itemID: ItemID?
        var issues: [ContentIssue] = []

        init(limits: ContentLoader.Limits, fileIndex: Int, malformed: Set<ContentIssue.Field>) {
            self.limits = limits
            self.fileIndex = fileIndex
            self.malformed = malformed
        }

        func issue(_ rule: ContentIssue.Rule) -> ContentIssue {
            ContentIssue(fileIndex: fileIndex, scenarioID: scenarioID, itemID: itemID, rule: rule)
        }

        mutating func report(_ rule: ContentIssue.Rule) {
            issues.append(issue(rule))
        }

        /// A required (or optional) string field. A present but empty, over-long or Tamil-script value is
        /// an issue; an absent optional field is not.
        mutating func string(_ value: String?, _ field: ContentIssue.Field, required: Bool = true) -> String? {
            if malformed.contains(field) {
                report(.unknownValue(field))
                return nil
            }
            return present(value, field, required: required)
        }

        mutating func strings(_ values: [String]?, _ field: ContentIssue.Field) -> [String]? {
            if malformed.contains(field) {
                report(.unknownValue(field))
                return nil
            }
            guard let values else {
                report(.missingField(field))
                return nil
            }
            guard !values.isEmpty else {
                report(.emptyField(field))
                return nil
            }
            let accepted = values.compactMap { accept($0, field) }
            return accepted.count == values.count ? accepted : nil
        }

        mutating func enumValue<Value: RawRepresentable>(
            _ raw: String?,
            _ field: ContentIssue.Field
        ) -> Value? where Value.RawValue == String {
            guard let text = string(raw, field) else { return nil }
            guard let value = Value(rawValue: text) else {
                report(.unknownValue(field))
                return nil
            }
            return value
        }

        mutating func tokens(_ entries: [RawItem.TokenEntry]?) -> [Token]? {
            if malformed.contains(.tokens) {
                report(.unknownValue(.tokens))
                return nil
            }
            guard let entries else {
                report(.missingField(.tokens))
                return nil
            }
            guard !entries.isEmpty else {
                report(.emptyField(.tokens))
                return nil
            }
            let tokens = entries.compactMap { token($0) }
            return tokens.count == entries.count ? tokens : nil
        }

        private mutating func token(_ entry: RawItem.TokenEntry) -> Token? {
            guard !entry.isMalformed else {
                report(.unknownValue(.tokens))
                return nil
            }
            let tamil = present(entry.tamil, .tokens, required: true)
            let english = present(entry.english, .tokens, required: true)
            guard let tamil, let english else { return nil }
            return Token(tamil: tamil, english: english)
        }

        private mutating func present(_ value: String?, _ field: ContentIssue.Field, required: Bool) -> String? {
            guard let value else {
                if required { report(.missingField(field)) }
                return nil
            }
            return accept(value, field)
        }

        private mutating func accept(_ value: String, _ field: ContentIssue.Field) -> String? {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                report(.emptyField(field))
                return nil
            }
            if value.count > limits.maxStringLength {
                report(.fieldTooLong(field))
                return nil
            }
            // Tamil script block, U+0B80 to U+0BFF: content is romanised, never script.
            if value.unicodeScalars.contains(where: { (0x0B80...0x0BFF).contains($0.value) }) {
                report(.tamilScriptInField(field))
                return nil
            }
            return value
        }
    }
}
