/// The only thing the app knows about the person using it: a display name (DECISIONS 030).
///
/// The initialiser stores exactly what it is given. Run user input through `ProfileNameValidator` first.
public struct UserProfile: Sendable, Equatable, Codable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}
