import Foundation

enum StravaImportState: Equatable {
    case loading
    case ready
    case failed(String)
}
