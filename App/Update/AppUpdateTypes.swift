import Foundation

struct AppRelease: Codable, Equatable, Sendable {
    let versao: String
    let build: Int
    let versao_app: String
    let notas: [String]
    var historico: [AppReleaseNotes]? = nil
}

struct AppReleaseNotes: Codable, Equatable, Sendable {
    let versao: String
    let notas: [String]
}

struct AppUpdate: Equatable, Sendable {
    let latest: String
    let installed: String
    let notes: [String]
}
