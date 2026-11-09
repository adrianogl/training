public struct FitnessOutlook: Sendable, Equatable {
    public var history: [FFFPoint]
    public var projection: [FFFPoint]
    public var peakFitness: Double?
    public var raceDayForm: Double?

    public init(history: [FFFPoint], projection: [FFFPoint], peakFitness: Double?, raceDayForm: Double?) {
        self.history = history
        self.projection = projection
        self.peakFitness = peakFitness
        self.raceDayForm = raceDayForm
    }
}
