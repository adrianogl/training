import RemoteSync

enum AccountScreen: Hashable {
    case login, signup, forgot
}

struct AccountSignOut: Equatable {
    let user: AuthUser?
    let deleted: Bool
}
