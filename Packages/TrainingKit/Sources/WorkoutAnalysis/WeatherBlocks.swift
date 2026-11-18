import TrainingCore

public func adjustForWeather(_ blocks: [WorkoutBlock], effect: WeatherEffect?) -> [WorkoutBlock] {
    guard let effect, effect.paceFactor > 0 else { return blocks }
    return blocks.map { block in
        var adjusted = block
        adjusted.weatherFactor = effect.paceFactor
        guard block.status == .slower, case let .speed(low, high)? = block.prescribed?.target,
              let speed = adjusted.weatherSpeed, speed >= low, high <= 0 || speed <= high else { return adjusted }
        adjusted.status = .inTarget
        adjusted.weatherRescued = true
        return adjusted
    }
}

