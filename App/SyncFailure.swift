import Foundation
import GarminAPI

enum SyncFailure: Equatable {
    case missingKey
    case invalidKey
    case rateLimited
    case offline
    case server(Int)
    case other(String)

    init(_ error: any Error) {
        switch error {
        case GarminAPIError.invalidKey, GarminAPIError.unauthorized:
            self = .invalidKey
        case GarminAPIError.rateLimited:
            self = .rateLimited
        case GarminAPIError.server(let status):
            self = .server(status)
        case let urlError as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(urlError.code):
            self = .offline
        default:
            self = .other(String(describing: error))
        }
    }

    var message: String {
        switch self {
        case .missingKey: "Cole a chave da Personal API em Ajustes."
        case .invalidKey: "O Garmin recusou a chave. Ela pode ter expirado."
        case .rateLimited: "O Garmin limitou as requisições. Tente de novo em alguns minutos."
        case .offline: "Sem conexão com o Garmin."
        case .server(let status): "O Garmin respondeu com erro \(status)."
        case .other(let description): "Falhou: \(description)"
        }
    }

    var suggestsNewKey: Bool { self == .invalidKey }
}
