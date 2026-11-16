import Foundation
import GarminAPI

public struct MFITTeacher: Sendable, Equatable, Codable, Identifiable {
    public var id: Int64
    public var name: String

    public init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }
}

public struct MFITCompletion: Sendable, Equatable, Codable {
    public var day: String
    public var start: Date?
    public var end: Date?
    public var effort: Int?

    public init(day: String, start: Date?, end: Date?, effort: Int?) {
        self.day = day
        self.start = start
        self.end = end
        self.effort = effort
    }

    public var minutes: Int? {
        guard let start, let end, end > start else { return nil }
        return Int((end.timeIntervalSince(start) / 60).rounded())
    }
}

public struct MFITWorkout: Sendable, Equatable, Codable, Identifiable {
    public var id: Int64
    public var title: String
    public var order: Int
    public var blocks: [StrengthBlock]
    public var completions: [MFITCompletion]

    public init(id: Int64, title: String, order: Int, blocks: [StrengthBlock], completions: [MFITCompletion]) {
        self.id = id
        self.title = title
        self.order = order
        self.blocks = blocks
        self.completions = completions
    }
}

public struct MFITProgram: Sendable, Equatable, Codable, Identifiable {
    public var id: Int64
    public var title: String
    public var start: String?
    public var end: String?
    public var teacherId: Int64?
    public var workouts: [MFITWorkout]

    public init(id: Int64, title: String, start: String?, end: String?, teacherId: Int64? = nil, workouts: [MFITWorkout]) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.teacherId = teacherId
        self.workouts = workouts
    }

    public func contains(_ iso: String) -> Bool {
        (start.map { $0 <= iso } ?? true) && (end.map { iso <= $0 } ?? true)
    }
}

public enum MFITError: Error, Equatable {
    case invalidLogin(String?)
    case unauthorized
    case unexpectedResponse(status: Int)
    case missingToken
}
