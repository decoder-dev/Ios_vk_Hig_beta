import Foundation

actor ProfileRepository {
    private let fixtures: FixtureStore

    init(fixtures: FixtureStore) {
        self.fixtures = fixtures
    }

    func fetchProfile(
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool
    ) async -> Result<UserProfile, AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.profile) {
            return .failure(.capabilityUnavailable("users.get"))
        }

        switch dataMode {
        case .fixtures:
            return .success(fixtures.profile)
        case .live:
            return .failure(.capabilityUnavailable("Profile requires VK ID session + users scope"))
        }
    }
}
