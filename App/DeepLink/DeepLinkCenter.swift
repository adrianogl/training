import Foundation
import Observation

@MainActor @Observable final class DeepLinkCenter {
    static let shared = DeepLinkCenter()

    private(set) var pending: DeepLink?

    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let link = DeepLink(url: url) else { return false }
        pending = link
        return true
    }

    func take() -> DeepLink? {
        defer { pending = nil }
        return pending
    }

    func take(_ matches: (DeepLink) -> Bool) -> DeepLink? {
        guard let pending, matches(pending) else { return nil }
        self.pending = nil
        return pending
    }
}
