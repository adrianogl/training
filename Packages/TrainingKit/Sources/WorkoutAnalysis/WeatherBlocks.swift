import TrainingCore

public func adjustForWeather(_ blocks: [WorkoutBlock], effect: WeatherEffect?) -> [WorkoutBlock] {
    let factor = effect?.paceFactor ?? 0
    guard factor > 0 || blocks.contains(where: { ($0.windFactor ?? 0) != 0 }) else { return blocks }
    return blocks.map { block in
        var adjusted = block
        if factor > 0 { adjusted.weatherFactor = factor }
        guard block.status == .slower, case let .speed(low, high)? = block.prescribed?.target,
              let speed = adjusted.weatherSpeed, speed >= low, high <= 0 || speed <= high else { return adjusted }
        adjusted.status = .inTarget
        adjusted.weatherRescued = true
        return adjusted
    }
}

