import Foundation

public enum RaceTransferError: Error, Equatable {
    case unsupportedVersion(Int)
}
