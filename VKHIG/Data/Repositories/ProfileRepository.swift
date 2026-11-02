import Foundation

actor ProfileRepository {
    private let fixtures: FixtureStore
    private let apiClient: VKAPIClient

    init(fixtures: FixtureStore, apiClient: VKAPIClient = VKAPIClient()) {
        self.fixtures = fixtures
        self.apiClient = apiClient
    }

    func fetchProfile(
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool,
        accessToken: String? = nil
    ) async -> Result<UserProfile, AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.profile) {
            guard let accessToken, !accessToken.isEmpty else {
                return .failure(.notAuthenticated)
            }
            do { return .success(try await VKIDAuthCoordinator.shared.fetchIdentity()) }
            catch let error as AppError { return .failure(error) }
            catch { return .failure(.network(error.localizedDescription)) }
        }

        switch dataMode {
        case .fixtures:
            return .success(fixtures.profile)
        case .live:
            if accessToken == nil || accessToken?.isEmpty == true {
                return .failure(.notAuthenticated)
            }
            return .failure(.capabilityUnavailable("Profile requires VK ID session + users scope"))
        }
    }
}
