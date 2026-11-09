public func readinessBreakdown(today: ReadinessInput, history: [ReadinessInput]) -> ReadinessBreakdown? {
    guard let current = readiness(today) else { return nil }
    let todayScores = readinessComponents(today)
    let recent = history.suffix(ReadinessConstants.normalWindowDays).map(readinessComponents)
    let presentWeight = todayScores.keys.reduce(0) { $0 + $1.weight }

    let factors = ReadinessComponent.allCases.map { component -> ReadinessFactor in
        let todayScore = todayScores[component]
        let samples = recent.compactMap { $0[component] }
        let normalScore = samples.count >= ReadinessConstants.normalMinimumDays ? mean(samples) : nil
        let weight = todayScore == nil ? 0 : component.weight / presentWeight
        var points: Double?
        if let todayScore, let normalScore { points = weight * (todayScore - normalScore) }
        return ReadinessFactor(component: component, todayScore: todayScore, normalScore: normalScore, points: points, weight: weight)
    }

    let ordered = factors.enumerated().sorted { lhs, rhs in
        let left = lhs.element, right = rhs.element
        if (left.todayScore == nil) != (right.todayScore == nil) { return right.todayScore == nil }
        let leftMagnitude = abs(left.points ?? 0), rightMagnitude = abs(right.points ?? 0)
        if leftMagnitude != rightMagnitude { return leftMagnitude > rightMagnitude }
        return lhs.offset < rhs.offset
    }.map(\.element)

    let present = ordered.filter { $0.todayScore != nil }
    var normal: Double?
    if present.allSatisfy({ $0.points != nil }) {
        normal = Double(current.score) - present.compactMap(\.points).reduce(0, +)
    }
    return ReadinessBreakdown(score: current.score, normal: normal, factors: ordered)
}
