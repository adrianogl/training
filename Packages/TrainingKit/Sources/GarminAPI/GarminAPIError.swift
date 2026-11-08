public enum GarminAPIError: Error, Equatable {
    case invalidKey
    case unauthorized
    case badRequest(path: String)
    case notAcceptable
    case rateLimited(path: String)
    case server(status: Int)
    case decoding(path: String)
}
