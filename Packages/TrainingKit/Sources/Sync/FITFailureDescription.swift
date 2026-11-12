import Foundation
import GarminAPI

enum FITFailureDescription {
    static func make(_ error: any Error) -> String {
        switch error {
        case let error as GarminAPIError:
            return "GarminAPIError: \(error)"
        case let error as URLError:
            return "URLError: code \(error.code.rawValue)"
        default:
            let nsError = error as NSError
            return "\(type(of: error)): \(nsError.domain) \(nsError.code)"
        }
    }
}
