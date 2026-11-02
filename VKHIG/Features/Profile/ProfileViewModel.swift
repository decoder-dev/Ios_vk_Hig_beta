import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    private let environment: AppEnvironment

    var state: LoadState<UserProfile> = .idle
    var usesFixtures = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        state = .loading
        usesFixtures = environment.dataMode == .fixtures && !environment.isLiveVKSession

        let result = await environment.profileRepository.fetchProfile(
            dataMode: environment.dataMode,
            capabilities: environment.capabilities,
            isNetworkReachable: environment.isNetworkReachable
        )
        switch result {
        case .success(let profile):
            state = .loaded(profile)
        case .failure(.offline):
            state = .offline
        case .failure(let error):
            state = .failed(error)
        }
    }
}
