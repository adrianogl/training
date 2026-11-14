import Foundation

enum CoursePointsBuilder {
    private typealias C = CoursePointsConstants

    static func climbs(_ profile: [GPXPoint]) -> [CourseClimb] {
        guard profile.count >= 2 else { return [] }
        var climbs: [CourseClimb] = []
        var start: GPXPoint?
        var previous = profile[0]
        func close(at end: GPXPoint) {
            guard let begin = start, end.distance - begin.distance >= C.minimumClimbMeters, end.altitude > begin.altitude else { return }
            climbs.append(CourseClimb(startKm: begin.distance / 1_000, endKm: end.distance / 1_000, gain: end.altitude - begin.altitude))
        }
        for point in profile.dropFirst() {
            let run = point.distance - previous.distance
            let grade = run > 0 ? (point.altitude - previous.altitude) / run : 0
            if grade >= C.minimumGrade {
                if start == nil { start = previous }
            } else if start != nil {
                close(at: previous)
                start = nil
            }
            previous = point
        }
        if start != nil { close(at: previous) }
        return climbs
    }

    static func gels(distance: Double, targetSeconds: Double?) -> [Double] {
        guard let targetSeconds, targetSeconds > 0, distance > 0 else { return [] }
        let paceSeconds = targetSeconds / (distance / 1_000)
        let everyKm = (C.gelEveryMinutes * 60 / paceSeconds).rounded()
        guard everyKm > 0 else { return [] }
        return stride(from: everyKm, to: distance / 1_000 - 1, by: everyKm).map { $0 }
    }

    static func water(_ text: String) -> [Double] {
        text.split(separator: Character(C.separator)).compactMap { Double($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }.sorted()
    }
}
