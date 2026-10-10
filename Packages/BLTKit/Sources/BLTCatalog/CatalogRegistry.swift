import BLTCore

/// What the files and items accepted so far have already claimed, so a later file cannot repeat it
/// (docs/DECISIONS.md 036, 038, 039). The earlier file wins. The loader owns one registry per load, which
/// is how imported lessons get the same catalog-wide checks as bundled ones.
struct CatalogRegistry: Sendable {
    var scenarioIDs: Set<ScenarioID> = []
    /// Level number to its title, set by the first accepted file that carries that level.
    var levelTitles: [Int: String] = [:]
    private var itemIDs: Set<ItemID> = []
    private var sourcePrompts: Set<String> = []
    private var canonicals: Set<String> = []

    /// The catalog-wide rules `item` breaks. A repeated id is reported alone: that item is a plain copy
    /// of an earlier one, so its prompt and answer would only repeat the same complaint.
    func clashes(for item: Item) -> [ContentIssue.Rule] {
        if itemIDs.contains(item.id) { return [.duplicateItemID] }
        var rules: [ContentIssue.Rule] = []
        if sourcePrompts.contains(Self.fingerprint(item.sourcePrompt)) { rules.append(.duplicateSourcePrompt) }
        if canonicals.contains(Self.fingerprint(item.canonical)) { rules.append(.duplicateCanonical) }
        return rules
    }

    mutating func accept(_ item: Item) {
        itemIDs.insert(item.id)
        sourcePrompts.insert(Self.fingerprint(item.sourcePrompt))
        canonicals.insert(Self.fingerprint(item.canonical))
    }

    /// Case, spacing and punctuation are ignored: only letters and numbers are compared.
    private static func fingerprint(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}
