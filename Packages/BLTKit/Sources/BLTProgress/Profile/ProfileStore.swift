/// Persistence for the one `UserProfile`. Implementations store exactly the profile they are given;
/// callers validate the name with `ProfileNameValidator` before saving.
public protocol ProfileStore: Sendable {
    /// `nil` means no profile has been saved yet.
    func load() async throws(ProfileStoreError) -> UserProfile?
    func save(_ profile: UserProfile) async throws(ProfileStoreError)
    /// Removes the profile. Succeeds when there is none.
    func erase() async throws(ProfileStoreError)
}
