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
            guard let first = pair.first, let timestamp = first else { return nil }
            let value = pair.count > 1 ? pair[1] : nil
            return BodyBatterySampleDTO(timestampMs: Int64(timestamp), value: value.map { Int($0) })
        }
    }
}
