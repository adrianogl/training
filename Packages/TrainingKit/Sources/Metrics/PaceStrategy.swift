import Foundation

public func paceStrategy(goalSeconds: Double, distance: Double, profile: [(distance: Double, altitude: Double)]?, manual: [Int: Double]) -> [KmPlan] {
    let kms = Int((distance / 1000).rounded(.up))
    guard kms > 0 else { return [] }
    let points = (profile ?? []).sorted { $0.distance < $1.distance }
    let base = goalSeconds / (distance / 1000)
    let flatCost = minettiCost(grade: 0)
    var plan = (0..<kms).map { index -> KmPlan in
        let start = Double(index) * 1000
        let length = kmLength(index, kms: kms, distance: distance)
        let grade = points.isEmpty ? 0 : (altitude(at: start + length, points) - altitude(at: start, points)) / length
        let label = kmLabel(index, kms: kms, grade: grade)
        if let fixed = manual[index] {
            return KmPlan(index: index, pace: fixed, grade: grade, label: label, manual: true)
        }
        var pace = base * minettiCost(grade: grade) / flatCost
        if index < RaceConstants.warmupKms { pace += RaceConstants.warmupOffset }
        if index >= kms - RaceConstants.finishKms { pace += RaceConstants.finishOffset }
        return KmPlan(index: index, pace: pace, grade: grade, label: label, manual: false)
    }
    let free = plan.filter { !$0.manual }
    let freeKm = free.reduce(0) { $0 + kmLength($1.index, kms: kms, distance: distance) / 1000 }
    guard freeKm > 0 else { return plan }
    let planned = plan.reduce(0) { $0 + $1.pace * kmLength($1.index, kms: kms, distance: distance) / 1000 }
    let shift = (goalSeconds - planned) / freeKm
    for index in plan.indices where !plan[index].manual {
        plan[index].pace += shift
    }
    return plan
}

private func kmLength(_ index: Int, kms: Int, distance: Double) -> Double {
    index < kms - 1 ? 1000 : distance - Double(kms - 1) * 1000
}

private func kmLabel(_ index: Int, kms: Int, grade: Double) -> String {
    if index >= kms - RaceConstants.finishKms { return RaceConstants.finishLabel }
    if index < RaceConstants.warmupKms { return RaceConstants.warmupLabel }
    if grade > RaceConstants.climbLabelGrade { return RaceConstants.climbLabel }
    if grade < -RaceConstants.climbLabelGrade { return RaceConstants.descentLabel }
    return RaceConstants.flatLabel
}

private func altitude(at distance: Double, _ points: [(distance: Double, altitude: Double)]) -> Double {
    guard let first = points.first, let last = points.last else { return 0 }
    if distance <= first.distance { return first.altitude }
    if distance >= last.distance { return last.altitude }
    let upper = points.firstIndex { $0.distance >= distance }!
    let a = points[upper - 1]
    let b = points[upper]
    guard b.distance > a.distance else { return b.altitude }
    return a.altitude + (b.altitude - a.altitude) * (distance - a.distance) / (b.distance - a.distance)
}
