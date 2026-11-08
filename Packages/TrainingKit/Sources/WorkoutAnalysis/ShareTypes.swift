import FITReader

public enum ShareTemplate: String, CaseIterable, Codable, Sendable {
    case storiesDark, transparent, blocks, strip

    public var hasBackground: Bool {
        self == .storiesDark || self == .blocks
    }
}

public enum ShareField: String, CaseIterable, Codable, Sendable {
    case route, title, distance, time, avgPace, avgHeartRate, activePace, elevation, readingLine

    public static let defaultEnabled = Set(allCases).subtracting([.elevation, .readingLine])

    public static func encode(_ fields: Set<ShareField>) -> String {
        allCases.filter(fields.contains).map(\.rawValue).joined(separator: ShareConstants.fieldSeparator)
    }

    public static func decode(_ text: String) -> Set<ShareField> {
        Set(text.split(separator: Character(ShareConstants.fieldSeparator)).compactMap { ShareField(rawValue: String($0)) })
    }
}

public struct ShareValue: Sendable, Equatable {
    public var field: ShareField
    public var value: String
    public var label: String

    public init(field: ShareField, value: String, label: String) {
        self.field = field
        self.value = value
        self.label = label
    }
}

public struct BlockBar: Sendable, Equatable {
    public var kind: BlockKind
    public var zone: Int?
    public var height: Double

    public init(kind: BlockKind, zone: Int?, height: Double) {
        self.kind = kind
        self.zone = zone
        self.height = height
    }
}

public struct ShareContent: Sendable, Equatable {
    public var title: String?
    public var values: [ShareValue]
    public var route: [Coordinate]?
    public var blockBars: [BlockBar]?
    public var readingLine: String?

    public init(title: String?, values: [ShareValue], route: [Coordinate]?, blockBars: [BlockBar]?, readingLine: String?) {
        self.title = title
        self.values = values
        self.route = route
        self.blockBars = blockBars
        self.readingLine = readingLine
    }
}

public struct WorkoutShareInput: Sendable, Equatable {
    public var title: String
    public var dateText: String
    public var distanceMeters: Double?
    public var movingSeconds: Double?
    public var avgPaceSecondsPerKm: Double?
    public var avgHeartRate: Double?
    public var activePaceSecondsPerKm: Double?
    public var elevationGain: Double?
    public var route: [Coordinate]
    public var blocks: [WorkoutBlock]
    public var readingLine: String?

    public init(
        title: String,
        dateText: String,
        distanceMeters: Double?,
        movingSeconds: Double?,
        avgPaceSecondsPerKm: Double?,
        avgHeartRate: Double?,
        activePaceSecondsPerKm: Double?,
        elevationGain: Double?,
        route: [Coordinate],
        blocks: [WorkoutBlock],
        readingLine: String?
    ) {
        self.title = title
        self.dateText = dateText
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.avgPaceSecondsPerKm = avgPaceSecondsPerKm
        self.avgHeartRate = avgHeartRate
        self.activePaceSecondsPerKm = activePaceSecondsPerKm
        self.elevationGain = elevationGain
        self.route = route
        self.blocks = blocks
        self.readingLine = readingLine
    }
}
