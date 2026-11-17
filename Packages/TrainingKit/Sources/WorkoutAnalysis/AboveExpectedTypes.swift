public enum AboveExpectedKind: String, Codable, Sendable {
    case heartRateAtPace, recoveryDrop
}

public struct AboveExpectedSignal: Codable, Sendable, Equatable {
    public var kind: AboveExpectedKind
    public var before: Double
    public var today: Double
    public var compared: Int

    public init(kind: AboveExpectedKind, before: Double, today: Double, compared: Int) {
        self.kind = kind
        self.before = before
        self.today = today
        self.compared = compared
    }
}
