import Foundation

public enum TrainerSignal: String, Codable, Sendable, CaseIterable {
    case hrv, restingHeartRate, sleep, load, performance, readiness

    public var isBody: Bool {
        switch self {
        case .hrv, .restingHeartRate, .sleep: true
        case .load, .performance, .readiness: false
        }
    }
}

public enum TrainerLightKind: String, Codable, Sendable {
    case body, training
}
