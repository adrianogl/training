public struct BodyBatterySampleDTO: Equatable, Sendable {
    public var timestampMs: Int64
    public var value: Int?

    public init(timestampMs: Int64, value: Int?) {
        self.timestampMs = timestampMs
        self.value = value
    }
}
