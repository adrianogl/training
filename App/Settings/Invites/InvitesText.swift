import Foundation
import RemoteSync
import SwiftUI

enum InvitesText {
    private typealias C = InvitesConstants

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }

    static func relative(_ date: Date, now: Date = .now) -> String {
        date.formatted(.relative(presentation: .named).locale(Locale(identifier: "pt_BR")))
    }

    static func detail(_ invite: AdminInvite) -> String {
        switch invite.status {
        case .pending: String(format: C.expiresFormat, day(invite.expiresAt))
        case .accepted: String(format: C.acceptedFormat, day(invite.acceptedAt ?? invite.createdAt))
        case .expired: String(format: C.expiredFormat, day(invite.expiresAt))
        case .canceled: String(format: C.canceledFormat, day(invite.createdAt))
        }
    }

    static func status(_ status: InviteStatus) -> String {
        switch status {
        case .pending: C.pendingStatus
        case .accepted: C.acceptedStatus
        case .expired: C.expiredStatus
        case .canceled: C.canceledStatus
        }
    }

    static func tint(_ status: InviteStatus) -> Color {
        switch status {
        case .pending: BrandColors.accent
        case .accepted, .canceled: BrandColors.dim
        case .expired: BrandColors.danger
        }
    }

    static func person(_ user: AdminUser) -> String {
        let seen = user.lastSeenAt.map { String(format: C.seenFormat, relative($0)) } ?? C.neverSeen
        let size = ByteCountFormatter.string(fromByteCount: Int64(user.dataBytes), countStyle: .file)
        return [user.garminConnected ? C.garminOn : C.garminOff, seen, size].joined(separator: " · ")
    }
}
