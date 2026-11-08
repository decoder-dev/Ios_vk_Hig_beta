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
            do { return .success(await enrich(try await VKSession.fetchIdentity())) }
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
            return .failure(.capabilityUnavailable("VK не предоставил доступ к профилю."))
        }
    }

    /// Adds photo, city, status, education and counters from `users.get` when VK allows it.
    /// The identity itself never depends on this call: a refusal keeps the VK ID profile.
    private func enrich(_ base: UserProfile) async -> UserProfile {
        let fields = "photo_200,city,status,online,counters,education"
        guard let response = try? await VKCatalogService.shared.request("users.get", ["fields": fields]),
              let j = response.items.first, j["id"].int == base.id || base.id == 0 else { return base }
        let counters = j["counters"]
        func count(_ key: String) -> Int? {
            if case .null = counters[key] { return nil }
            return Int(counters[key].int)
        }
        let city = j["city"]["title"].string
        let status = j["status"].string
        let university = j["university_name"].string
        return UserProfile(
            id: base.id,
            displayName: base.displayName,
            initials: base.initials,
            city: city.isEmpty ? base.city : city,
            statusText: status.isEmpty ? base.statusText : status,
            avatarURL: VKCatalogService.avatarURL(j) ?? base.avatarURL,
            isOnline: j["online"].flag,
            counters: ProfileCounters(friends: count("friends"), communities: count("groups") ?? count("pages"), photos: count("photos"), videos: count("videos")),
            university: university.isEmpty ? nil : university
        )
    }
}
