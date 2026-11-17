public extension MetricKind {
    var predictionMeters: Double? {
        InsightsConstants.predictionDistances[self]
    }
}
