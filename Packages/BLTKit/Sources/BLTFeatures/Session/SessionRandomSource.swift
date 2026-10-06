/// The random source the session view model shuffles with. A concrete value type rather than
/// `any RandomNumberGenerator`: `SessionMachine` takes `inout some RandomNumberGenerator`, and an
/// existential cannot be opened through `inout`. It is `Sendable` and needs no unsafe escape hatch.
///
/// Production uses `.system`. Tests and previews use `.seeded(_:)` (SplitMix64) so option order
/// is reproducible.
public struct SessionRandomSource: RandomNumberGenerator, Sendable {
    private var seededState: UInt64?

    /// The system generator. Not reproducible.
    public static let system = SessionRandomSource(seededState: nil)

    /// A deterministic generator: the same seed always produces the same sequence.
    public static func seeded(_ seed: UInt64) -> SessionRandomSource {
        SessionRandomSource(seededState: seed)
    }

    public mutating func next() -> UInt64 {
        guard var state = seededState else {
            var system = SystemRandomNumberGenerator()
            return system.next()
        }
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        seededState = state
        return mixed ^ (mixed >> 31)
    }
}
