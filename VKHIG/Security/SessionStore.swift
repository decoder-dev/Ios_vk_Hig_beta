import Foundation
import Observation

/// Session façade. Live tokens live in Keychain via VKIDAuthCoordinator.
@MainActor
@Observable
final class SessionStore {
    enum Mode: String, Sendable {
        /// Local UI shell without VK credentials (fixtures allowed).
        case shellPreview
        /// Real VK ID session (Stage 2+, after credentials).
        case authenticated
    }

    private(set) var mode: Mode?
    private let authCoordinator: VKIDAuthCoordinator

    var isAuthenticated: Bool { mode != nil }

    var isLiveVKSession: Bool { mode == .authenticated }

    init(authCoordinator: VKIDAuthCoordinator? = nil) {
        let authCoordinator = authCoordinator ?? .shared
        self.authCoordinator = authCoordinator
        if authCoordinator.restoreSessionIfPossible() || AccountManager.shared.activeAccount.value != nil {
            // Token present but scopes unverified — still mark authenticated for routing;
            // repositories stay capability-gated.
            mode = .authenticated
        }
    }

    /// Opens TabView with fixture-backed repositories. Does not contact VK.
    func enterShellWithoutAuth() {
        mode = .shellPreview
    }

    /// Called when the multi-account state changed (account added, switched, removed or expired).
    func reconcileWithAccounts() {
        if VKSession.hasLiveSession { mode = .authenticated }
        else if mode == .authenticated { mode = nil }
    }

    func signInWithVKID() async -> Result<Void, VKIDAuthError> {
        let result = await authCoordinator.authorize()
        if case .success = result {
            mode = .authenticated
        }
        return result
    }

    func signOut() {
        authCoordinator.clearSession()
        mode = nil
    }
}
