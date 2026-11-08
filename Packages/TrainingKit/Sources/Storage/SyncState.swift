import Foundation
import SwiftData

@Model
public final class SyncState {
    public var firstLoadCompleted: Bool = false
    public var lastSync: Date? = nil
    public var lastActivityStart: Date? = nil
    public var resumeDailyFrom: String? = nil
    public var resumeHRVFrom: String? = nil
    public var resumeSleepFrom: String? = nil
    public var resumeBodyBatteryFrom: String? = nil
    public var resumeActivityStart: Int? = nil

    public init(
        firstLoadCompleted: Bool = false,
        lastSync: Date? = nil,
        lastActivityStart: Date? = nil,
        resumeDailyFrom: String? = nil,
        resumeHRVFrom: String? = nil,
        resumeSleepFrom: String? = nil,
        resumeBodyBatteryFrom: String? = nil,
        resumeActivityStart: Int? = nil
    ) {
        self.firstLoadCompleted = firstLoadCompleted
        self.lastSync = lastSync
        self.lastActivityStart = lastActivityStart
        self.resumeDailyFrom = resumeDailyFrom
        self.resumeHRVFrom = resumeHRVFrom
        self.resumeSleepFrom = resumeSleepFrom
        self.resumeBodyBatteryFrom = resumeBodyBatteryFrom
        self.resumeActivityStart = resumeActivityStart
    }

    public func clearResumeCursors() {
        resumeDailyFrom = nil
        resumeHRVFrom = nil
        resumeSleepFrom = nil
        resumeBodyBatteryFrom = nil
        resumeActivityStart = nil
    }
}
