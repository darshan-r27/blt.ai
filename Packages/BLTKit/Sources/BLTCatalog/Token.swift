public struct Token: Sendable, Equatable {
    public let tamil: String
    public let english: String

    public init(tamil: String, english: String) {
        self.tamil = tamil
        self.english = english
    }
}
