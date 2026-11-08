import Foundation
import SwiftData

@Model
public final class SyncState {
    public var firstLoadCompleted: Bool = false
    public var lastSync: Date? = nil
    public var lastActivityStart: Date? = nil

    public init(
        firstLoadCompleted: Bool = false,
        lastSync: Date? = nil,
        lastActivityStart: Date? = nil
    ) {
        self.firstLoadCompleted = firstLoadCompleted
        self.lastSync = lastSync
        self.lastActivityStart = lastActivityStart
    }
}
