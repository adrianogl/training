import TrainingCore

public func raceBlock(raceDay: Day, today: Day, weeklyKm: [Day: Double]) -> [BlockWeek] {
    let raceWeek = raceDay.weekStart
    let currentWeek = today.weekStart
    let recent = (1...RaceConstants.projectionWeeks).map { weeklyKm[currentWeek.adding(days: -7 * $0)] ?? 0 }
    let projection = mean(recent) ?? 0
    return (0..<RaceConstants.blockWeeks).map { offset in
        let start = raceWeek.adding(days: -7 * (RaceConstants.blockWeeks - 1 - offset))
        if start > currentWeek {
            return BlockWeek(start: start, km: projection, projected: true)
        }
        return BlockWeek(start: start, km: weeklyKm[start] ?? 0, projected: false)
    }
}
