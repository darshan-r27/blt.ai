/// A `ProfileStore` that keeps the profile in memory. For tests and previews; behaves like
/// `FileProfileStore` minus the failure modes that only a disk can have.
public actor InMemoryProfileStore: ProfileStore {
    private var profile: UserProfile?

    public init(initial: UserProfile? = nil) {
        profile = initial
    }

    public func load() async throws(ProfileStoreError) -> UserProfile? {
        profile
    }

    public func save(_ profile: UserProfile) async throws(ProfileStoreError) {
        self.profile = profile
    }

    public func erase() async throws(ProfileStoreError) {
        profile = nil
    }
}
