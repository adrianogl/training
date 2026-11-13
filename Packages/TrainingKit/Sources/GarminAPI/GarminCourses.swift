import Foundation

public struct GarminCourseSummary: Sendable, Equatable, Identifiable, Hashable {
    public let id: Int64
    public let name: String
    public let meters: Double?
    public let elevationGain: Double?
}

public enum GarminCourses {
    struct ListItem: Decodable {
        let courseId: Int64
        let courseName: String?
        let distanceInMeters: Double?
        let elevationGainInMeters: Double?
    }

    struct Detail: Decodable {
        struct Point: Decodable {
            let latitude: Double
            let longitude: Double
            let elevation: Double?
        }

        let courseName: String?
        let geoPoints: [Point]?
    }

    public static func list(client: GarminAccountClient) async throws -> [GarminCourseSummary] {
        let items = try JSONDecoder().decode([ListItem].self, from: try await client.get(GarminAccountEndpoints.coursesPath))
        return items.map { GarminCourseSummary(id: $0.courseId, name: $0.courseName ?? "", meters: $0.distanceInMeters, elevationGain: $0.elevationGainInMeters) }
    }

    public static func gpx(client: GarminAccountClient, id: Int64) async throws -> Data {
        let data = try await client.get(GarminAccountEndpoints.coursesPath + "/" + String(id))
        return gpx(from: try JSONDecoder().decode(Detail.self, from: data))
    }

    static func gpx(from detail: Detail) -> Data {
        let points = (detail.geoPoints ?? []).map { point in
            let elevation = point.elevation.map { "<ele>\($0)</ele>" } ?? ""
            return "<trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\">\(elevation)</trkpt>"
        }
        let name = escape(detail.courseName ?? "")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="trAIning" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>\(name)</name><trkseg>\(points.joined())</trkseg></trk></gpx>
        """
        return Data(xml.utf8)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}
