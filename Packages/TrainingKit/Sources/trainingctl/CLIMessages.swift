import Foundation
import GarminAPI

enum CLIMessages {
    static func message(for error: Error) -> String {
        switch error {
        case CLIError.usage(let detail):
            return "\(detail)\n\(CLIConstants.usage)"
        case CLIError.missingKey(let path):
            return "Chave do Garmin não encontrada. Grave a chave da Personal API em \(path) (um arquivo só com a chave, permissão 600)."
        case CLIError.emptyKey(let path):
            return "O arquivo da chave do Garmin está vazio: \(path)"
        case let error as GarminAPIError:
            return garminMessage(error)
        default:
            return "Erro: \(error.localizedDescription)"
        }
    }

    private static func garminMessage(_ error: GarminAPIError) -> String {
        switch error {
        case .invalidKey:
            return "Garmin recusou a chave (inválida ou revogada). Gere uma nova e grave em \(SyncCommand.keyPath().path)."
        case .unauthorized:
            return "Garmin respondeu 401 mesmo depois de renovar o token."
        case .badRequest(let path):
            return "Garmin respondeu 400 em \(path)."
        case .notAcceptable:
            return "Garmin respondeu 406 (header Accept não aceito)."
        case .rateLimited(let path):
            return "Garmin limitou as requisições (429) em \(path), mesmo depois dos retries. Espere alguns minutos e rode o sync de novo: ele continua de onde parou."
        case .client(let status, let path):
            return "Garmin respondeu \(status) em \(path)."
        case .server(let status):
            return "Garmin respondeu \(status)."
        case .decoding(let path):
            return "Resposta do Garmin em formato inesperado em \(path)."
        }
    }
}
