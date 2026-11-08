import TrainingCore

public struct FFFPoint: Sendable, Equatable {
    public var day: Day
    public var fitness: Double
    public var fatigue: Double
    public var form: Double

    public init(day: Day, fitness: Double, fatigue: Double, form: Double) {
        self.day = day
        self.fitness = fitness
        self.fatigue = fatigue
        self.form = form
    }
}

public func fitnessFatigueForm(dailyLoad: [Day: Double], from: Day, to: Day) -> [FFFPoint] {
    guard from <= to else { return [] }
    var fitness = 0.0
    var fatigue = 0.0
    var points: [FFFPoint] = []
    var day = from
    while day <= to {
        let load = dailyLoad[day] ?? 0
        let form = fitness - fatigue
        fitness += (load - fitness) / 42
        fatigue += (load - fatigue) / 7
        points.append(FFFPoint(day: day, fitness: fitness, fatigue: fatigue, form: form))
        day = day.adding(days: 1)
    }
    return points
}

public func acuteChronicRatio(dailyLoad: [Day: Double], on: Day) -> Double? {
    func sum(days: Int) -> Double {
        (0..<days).reduce(0) { $0 + (dailyLoad[on.adding(days: -$1)] ?? 0) }
    }
    let chronicSum = sum(days: 28)
    guard chronicSum > 0 else { return nil }
    return sum(days: 7) / (chronicSum / 4)
}
