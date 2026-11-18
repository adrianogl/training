import FITReader
import TrainingCore

private typealias C = AnalysisConstants

func windAgainst(_ blocks: [WorkoutBlock], kilometers: BlockKilometers, weather: WeatherEffect?) -> [Finding] {
    guard let windSpeed = weather?.weather.windSpeed, windSpeed > 0 else { return [] }
    let free = kilometers.isEmpty && blocks.allSatisfy { $0.prescribed == nil }
    let sources: [(position: Int?, startKm: Int, rows: [WorkoutBlock])] = free
        ? [(nil, 0, blocks)]
        : kilometers.sorted { $0.key < $1.key }.compactMap { position, rows in
            guard blocks.indices.contains(position), blocks[position].kind == .active else { return nil }
            let startKm = blocks[..<position].reduce(0) { $0 + $1.distance } / C.metersPerKilometer
            return (position, Int(startKm.rounded()), rows)
        }
    var findings: [Finding] = []
    for source in sources {
        var segment: (from: Int, rows: [WorkoutBlock])?
        func close() {
            guard let current = segment else { return }
            findings.append(windFinding(position: source.position, from: current.from, rows: current.rows, windSpeed: windSpeed))
            segment = nil
        }
        for (index, row) in source.rows.enumerated() {
            guard row.distance >= C.fullLapMinimumDistance, (windSeconds(row) ?? 0) >= RunWeatherConstants.windEffectSeconds else {
                close()
                continue
            }
            if segment == nil { segment = (source.startKm + index + 1, []) }
            segment?.rows.append(row)
        }
        close()
    }
    return findings
}

private func windFinding(position: Int?, from: Int, rows: [WorkoutBlock], windSpeed: Double) -> Finding {
    let distance = rows.reduce(0) { $0 + $1.distance }
    let seconds = rows.reduce(0) { $0 + $1.seconds }
    let calm = rows.reduce(0) { total, row in total + row.seconds / (1 + (row.windFactor ?? 0)) }
    let kilometers = distance / C.metersPerKilometer
    return Finding(group: .positive, kind: .windAgainst, blockOrdinal: position, facts: [
        FindingFact.fromKilometer: Double(from),
        FindingFact.toKilometer: Double(from + rows.count - 1),
        FindingFact.windSpeed: windSpeed * RunWeatherConstants.metersPerSecondToKmh,
        FindingFact.headwind: rows.reduce(0) { $0 + ($1.headwind ?? 0) } / Double(rows.count) * RunWeatherConstants.metersPerSecondToKmh,
        FindingFact.pace: seconds / kilometers,
        FindingFact.mildPace: calm / kilometers,
    ])
}

func runFormFade(_ blocks: [WorkoutBlock], samples: [FITSample]) -> [Finding] {
    guard samples.contains(where: { $0.cadence != nil || $0.stanceTime != nil }) else { return [] }
    let ordered = samples.sorted { $0.t < $1.t }
    if blocks.allSatisfy({ $0.prescribed == nil }) {
        return formFinding(position: nil, window: ordered).map { [$0] } ?? []
    }
    return blocks.enumerated().compactMap { position, block in
        guard block.kind == .active, block.seconds >= C.formMinimumSeconds, let start = block.laps.first?.startOffset else { return nil }
        let end = blocks[(position + 1)...].lazy.compactMap { $0.laps.first?.startOffset }.first ?? .infinity
        return formFinding(position: position, window: ordered.filter { $0.t >= start && $0.t < end })
    }
}

private func formFinding(position: Int?, window: [FITSample]) -> Finding? {
    let moving = window.filter { ($0.speed ?? 0) > C.pauseMaximumSpeed }
    guard let first = moving.first?.t, let last = moving.last?.t, last - first >= C.formMinimumSeconds else { return nil }
    let third = (last - first) / 3
    let opening = moving.filter { $0.t < first + third }
    let closing = moving.filter { $0.t >= last - third }
    guard let openingSpeed = mean(opening.compactMap(\.speed)), let closingSpeed = mean(closing.compactMap(\.speed)),
          closingSpeed <= openingSpeed * (1 + C.formSpeedTolerance) else { return nil }
    var facts: [String: Double] = [:]
    var fading = false
    if let from = mean(opening.compactMap(\.cadence)), let to = mean(closing.compactMap(\.cadence)) {
        facts[FindingFact.cadenceFrom] = from
        facts[FindingFact.cadenceTo] = to
        fading = fading || from - to >= C.cadenceDrop
    }
    if let from = mean(opening.compactMap(\.stanceTime)), let to = mean(closing.compactMap(\.stanceTime)), from > 0 {
        facts[FindingFact.stanceFrom] = from
        facts[FindingFact.stanceTo] = to
        fading = fading || to / from - 1 >= C.stanceRise
    }
    guard fading else { return nil }
    return Finding(group: .attention, kind: .runFormFade, blockOrdinal: position, facts: facts)
}

func dayFacts(_ day: DayCondition?) -> [String: Double] {
    guard let day else { return [:] }
    var facts: [String: Double] = [:]
    if let sleep = day.sleepSeconds, sleep < C.shortSleepSeconds { facts[FindingFact.sleepSeconds] = Double(sleep) }
    if let score = day.sleepScore, score < C.lowSleepScore { facts[FindingFact.sleepScore] = Double(score) }
    if day.hrvBelowBalanced { facts[FindingFact.hrvLow] = 1 }
    if let battery = day.bodyBattery, battery < C.lowBodyBattery { facts[FindingFact.bodyBattery] = Double(battery) }
    if let previous = day.previousDay { facts[FindingFact.previousDay] = Double(previous.rawValue) }
    return facts
}

private func mean(_ values: [Double]) -> Double? {
    values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
}
