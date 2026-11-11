import Foundation
import SwiftData

@Model
public final class ThresholdHistoryRecord {
    public var sport: String = ""
    public var day: String = ""
    public var heartRate: Int = 0

    public init(sport: String, day: String, heartRate: Int) {
        self.sport = sport
        self.day = day
        self.heartRate = heartRate
    }
}
