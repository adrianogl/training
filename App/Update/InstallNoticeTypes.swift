import Foundation

enum InstallEvent: Equatable {
    case updated(version: String, notes: [String])
    case renewed(expiry: Date)
}

struct InstalledCard: Codable, Equatable {
    let version: String
    let notes: [String]
    let day: String
}
