import Foundation

extension AccountLink {
    private typealias C = AccountConstants

    init?(url: URL) {
        guard url.scheme == AppConstants.urlScheme,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        switch url.host() {
        case C.linkInviteHost: guard let token = value(C.linkInviteQuery) else { return nil }; self = .invite(token)
        case C.linkVerifyHost: guard let token = value(C.linkTokenQuery) else { return nil }; self = .verify(token)
        case C.linkResetHost: guard let token = value(C.linkTokenQuery) else { return nil }; self = .reset(token)
        default: return nil
        }
    }
}
