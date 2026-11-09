import TrainingCore

public func predictionSeries(distance: Double, efforts: [Effort], from: Day, to: Day) -> [(Day, Double)] {
    var series: [(Day, Double)] = []
    var day = from
    while day <= to {
        if let seconds = predict(distance: distance, efforts: efforts, on: day) {
            series.append((day, seconds))
        }
        day = day.adding(days: 1)
    }
    return series
}
