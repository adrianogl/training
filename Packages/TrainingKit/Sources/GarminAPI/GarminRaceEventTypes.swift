public struct GarminRaceEvent: Sendable, Equatable, Codable, Identifiable {
    public let id: Int64
    public let name: String
    public let day: String
    public let startTime: String?
    public let distanceMeters: Double?
    public let courseId: Int64?
    public let url: String?

    public init(id: Int64, name: String, day: String, startTime: String?, distanceMeters: Double?, courseId: Int64?, url: String?) {
        self.id = id
        self.name = name
        self.day = day
        self.startTime = startTime
        self.distanceMeters = distanceMeters
        self.courseId = courseId
        self.url = url
    }
}
