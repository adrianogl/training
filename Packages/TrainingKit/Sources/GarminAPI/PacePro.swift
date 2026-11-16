import Foundation

public enum PacePro {
    static let waterType = "WATER"

    public static func summaries(client: GarminAccountClient) async throws -> [PaceProSummary] {
        let data = try await client.get(GarminAccountEndpoints.paceBandsSummariesPath)
        return try parseSummaries(data)
    }

    public static func plan(id: Int64, client: GarminAccountClient) async throws -> PaceProPlan? {
        try parsePlan(try await client.get(GarminAccountEndpoints.paceBandPathPrefix + String(id)))
    }

    public static func water(courseId: Int64, client: GarminAccountClient) async throws -> [Double] {
        try parseWater(try await client.get(GarminAccountEndpoints.coursesPath + "/" + String(courseId)))
    }

    static func parseWater(_ data: Data) throws -> [Double] {
        try JSONDecoder().decode(CourseDTO.self, from: data).coursePoints?
            .filter { $0.coursePointType == waterType }
            .compactMap(\.distance)
            .sorted() ?? []
    }

    static func parseSummaries(_ data: Data) throws -> [PaceProSummary] {
        try JSONDecoder().decode([PaceBandSummaryDTO].self, from: data).map(summary)
    }

    static func parsePlan(_ data: Data) throws -> PaceProPlan? {
        let dto = try JSONDecoder().decode(PaceBandDTO.self, from: data)
        guard let head = dto.paceBandSummary else { return nil }
        let splits = (dto.paceBandSplits ?? []).compactMap { split -> PaceProSplit? in
            guard let distance = split.cumulativeDistanceFromStart, let time = split.cumulativeTimeFromStart else { return nil }
            return PaceProSplit(distance: distance, time: time)
        }
        return PaceProPlan(summary: summary(head), splits: splits.sorted { $0.distance < $1.distance })
    }

    private static func summary(_ dto: PaceBandSummaryDTO) -> PaceProSummary {
        PaceProSummary(id: dto.paceBandPk, name: dto.name ?? "", distance: dto.totalDistance ?? 0, goalSeconds: dto.goalTime, created: dto.createdDate, courseId: dto.courseId)
    }

    public static func match(_ summaries: [PaceProSummary], distance: Double) -> PaceProSummary? {
        summaries
            .filter { distance > 0 && abs($0.distance - distance) / distance <= 0.03 }
            .max { ($0.created ?? "") < ($1.created ?? "") }
    }
}
