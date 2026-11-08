import Foundation

extension ActivityRecord {
    public var hasStart: Bool { start != .distantPast }
}
