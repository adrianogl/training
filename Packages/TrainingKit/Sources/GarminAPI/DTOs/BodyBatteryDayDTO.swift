import TrainingCore

public struct BodyBatteryDayDTO: Decodable, Equatable, Sendable {
    public var day: Day
    public var charged: Int?
    public var drained: Int?
    public var samples: [BodyBatterySampleDTO]

    public init(day: Day, charged: Int? = nil, drained: Int? = nil, samples: [BodyBatterySampleDTO] = []) {
        self.day = day
        self.charged = charged
        self.drained = drained
        self.samples = samples
    }

    private enum CodingKeys: String, CodingKey {
        case date, charged, drained, bodyBatteryValuesArray
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Day.self, forKey: .date)
        charged = try c.decodeRoundedInt(forKey: .charged)
        drained = try c.decodeRoundedInt(forKey: .drained)
        let raw = try c.decodeIfPresent([[Double?]].self, forKey: .bodyBatteryValuesArray) ?? []
        samples = raw.compactMap { pair in
            guard let first = pair.first, let rawTimestamp = first, let timestamp = Int64(exactly: rawTimestamp.rounded()) else { return nil }
            guard let rawValue = pair.count > 1 ? pair[1] : nil else {
                return BodyBatterySampleDTO(timestampMs: timestamp, value: nil)
            }
            guard let value = Int(exactly: rawValue.rounded()) else { return nil }
            return BodyBatterySampleDTO(timestampMs: timestamp, value: value)
        }
    }
}
