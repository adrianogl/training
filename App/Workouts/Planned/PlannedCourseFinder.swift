import Foundation
import GarminAPI
import Metrics

enum PlannedCourseFinder {
    private typealias C = PlannedExtrasConstants

    static func best(_ courses: [GarminCourseSummary], plannedMeters: Double) -> (course: GarminCourseSummary, laps: Int)? {
        var options: [(course: GarminCourseSummary, laps: Int, gap: Double)] = []
        for course in courses {
            guard let meters = course.meters, meters > 0 else { continue }
            for laps in 1...C.maxLaps {
                let gap = abs(meters * Double(laps) - plannedMeters) / plannedMeters
                if gap <= C.courseTolerance { options.append((course, laps, gap)) }
            }
        }
        return options.min { ($0.laps, $0.gap) < ($1.laps, $1.gap) }.map { ($0.course, $0.laps) }
    }

    static func suggestion(client: GarminAccountClient, plannedMeters: Double) async -> CourseSuggestion? {
        guard plannedMeters > 0, let courses = try? await GarminCourses.list(client: client),
              let pick = best(courses, plannedMeters: plannedMeters), let meters = pick.course.meters else { return nil }
        let profile = (try? await GarminCourses.gpx(client: client, id: pick.course.id)).flatMap { try? gpxProfile($0) } ?? []
        return CourseSuggestion(
            name: pick.course.name,
            lapKilometers: meters / WorkoutConstants.metersPerKilometer,
            laps: pick.laps,
            elevationGain: pick.course.elevationGain,
            profile: thinned(profile.map(\.altitude), limit: C.profilePoints)
        )
    }

    private static func thinned(_ values: [Double], limit: Int) -> [Double] {
        guard values.count > limit, limit > 1 else { return values }
        let step = Double(values.count - 1) / Double(limit - 1)
        return (0..<limit).map { values[Int((Double($0) * step).rounded())] }
    }
}
