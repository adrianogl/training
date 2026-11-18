import RemoteSync

enum AccountScreen: Hashable {
    case login, signup, forgot
}

struct AccountSignOut: Equatable {
    let user: AuthUser?
    let deleted: Bool
}

enum AccountLink: Identifiable, Equatable {
    case invite(String)
    case verify(String)
    case reset(String)

    var id: String {
        switch self {
        case .invite(let token): "invite-\(token)"
        case .verify(let token): "verify-\(token)"
        case .reset(let token): "reset-\(token)"
        }
    }
}

enum VerifyState: Equatable {
    case checking, verified, expired
}
