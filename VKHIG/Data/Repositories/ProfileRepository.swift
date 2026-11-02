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
            do {
                let response: VKJSON = try await apiClient.call(method:"users.get", parameters:["fields":"city,status"], accessToken:accessToken, apiVersion:AppSecrets.vkAPIVersion)
                guard let user = response.items.first else { return .failure(.decoding) }
                let name = await VKCatalogService.name(user)
                return .success(UserProfile(id:user["id"].int, displayName:name, initials:await VKCatalogService.initials(name), city:user["city"]["title"].string, statusText:user["status"].string))
            } catch { return .failure(.network(error.localizedDescription)) }
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
