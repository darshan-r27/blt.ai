#if DEBUG
import BLTProgress

/// A profile store whose `load()` always throws, for previewing the profile-load problem screen.
struct PreviewFailingProfileStore: ProfileStore {
    let loadError: ProfileStoreError

    func load() async throws(ProfileStoreError) -> UserProfile? {
        throw loadError
    }

    func save(_ profile: UserProfile) async throws(ProfileStoreError) {}

    func erase() async throws(ProfileStoreError) {}
}
#endif
