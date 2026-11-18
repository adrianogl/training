import FITReader
import Foundation
import TrainingCore

private typealias W = RunWeatherConstants

public func applyWind(_ blocks: [WorkoutBlock], samples: [FITSample], weather: RunWeather?) -> [WorkoutBlock] {
    guard let speed = weather?.windSpeed, let from = weather?.windFrom, speed > 0 else { return blocks }
    let headwinds = sampleHeadwinds(samples, windSpeed: speed, windFrom: from)
    guard !headwinds.isEmpty else { return blocks }
    return blocks.enumerated().map { position, block in
        guard let start = block.laps.first?.startOffset else { return block }
        let end = blocks[(position + 1)...].lazy.compactMap { $0.laps.first?.startOffset }.first
            ?? block.laps.last.map { $0.startOffset + $0.timerSeconds } ?? start
        let inside = headwinds.filter { $0.t >= start && $0.t < end }
        guard !inside.isEmpty else { return block }
        var adjusted = block
        adjusted.headwind = inside.reduce(0) { $0 + $1.headwind } / Double(inside.count)
        adjusted.windFactor = inside.reduce(0) { $0 + WeatherAdjustment.windCost(headwind: $1.headwind) } / Double(inside.count)
        return adjusted
    }
}

public func applyWind(_ kilometers: BlockKilometers, samples: [FITSample], weather: RunWeather?) -> BlockKilometers {
    kilometers.mapValues { applyWind($0, samples: samples, weather: weather) }
}

public func windSeconds(_ block: WorkoutBlock) -> Double? {
    guard let factor = block.windFactor, let speed = block.avgSpeed, speed > 0 else { return nil }
    let pace = AnalysisConstants.metersPerKilometer / speed
    return pace - pace / (1 + factor)
}

private func sampleHeadwinds(_ samples: [FITSample], windSpeed: Double, windFrom: Double) -> [(t: Double, headwind: Double)] {
    let located = samples.filter { $0.lat != nil && $0.lon != nil }.sorted { $0.t < $1.t }
    var result: [(t: Double, headwind: Double)] = []
    var anchor = located.first
    for sample in located.dropFirst() {
        guard let previous = anchor, let lat1 = previous.lat, let lon1 = previous.lon, let lat2 = sample.lat, let lon2 = sample.lon,
              meters(lat1, lon1, lat2, lon2) >= W.minimumHeadingMeters else { continue }
        let heading = bearing(lat1, lon1, lat2, lon2)
        result.append((sample.t, WeatherAdjustment.headwind(windSpeed: windSpeed, windFrom: windFrom, heading: heading)))
        anchor = sample
    }
    return result
}

private func bearing(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let phi1 = lat1 * .pi / 180
    let phi2 = lat2 * .pi / 180
    let delta = (lon2 - lon1) * .pi / 180
    let y = sin(delta) * cos(phi2)
    let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(delta)
    return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
}

private func meters(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let radius = 6_371_000.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * radius * atan2(sqrt(a), sqrt(1 - a))
}
