import RemoteSync

extension InviteDelivery: @retroactive Identifiable {
    public var id: String { invite.id + link }
}

extension InviteChannel {
    var title: String {
        switch self {
        case .email: "E-mail"
        case .whatsapp: "WhatsApp"
        case .link: "Link"
        }
    }
}
