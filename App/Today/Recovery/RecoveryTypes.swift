import Foundation

struct RecoveryRun: Equatable, Sendable, Codable {
    let title: String
    let end: Date
    let aerobicEffect: Double?
    let anaerobicEffect: Double?
    let typicalHour: Int
    var weekendHour: Int? = nil
    var kind: SessionKind? = nil
    var kilometers: Double? = nil
    var averageHeartRate: Int? = nil
}

enum RecoveryStatus: Equatable {
    case relaxed
    case recovered
    case almost
    case early
}

struct RecoveryNext: Equatable, Identifiable {
    let title: String
    let kind: SessionKind
    let kilometers: Double?
    let start: Date
    let hoursFromReady: Double
    let status: RecoveryStatus

    var id: String { "\(start.timeIntervalSince1970)-\(title)" }
}

struct RecoveryEstimate: Equatable {
    let title: String
    let kind: SessionKind?
    let kilometers: Double?
    let averageHeartRate: Int?
    let end: Date
    let now: Date
    let hours: Int
    let readyAt: Date
    let progress: Double
    let remainingHours: Int
    let upcoming: [RecoveryNext]
    let axisEnd: Date
    let advice: String?

    func position(of date: Date) -> Double {
        let span = axisEnd.timeIntervalSince(end)
        guard span > 0 else { return 0 }
        return min(max(date.timeIntervalSince(end) / span, 0), 1)
    }
}

extension RecoveryNext {
    var detail: String {
        typealias C = RecoveryConstants
        let hours = Int(abs(hoursFromReady).rounded())
        if hoursFromReady >= 0 { return String(format: C.afterReadyFormat, hours) }
        return String(format: kind.isHard ? C.beforeReadyFormat : C.easyBeforeFormat, hours)
    }
}
