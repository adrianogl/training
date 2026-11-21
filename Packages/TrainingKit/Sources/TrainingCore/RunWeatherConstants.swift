public enum RunWeatherConstants {
    public static let heatBands: [(sumFahrenheit: Double, factor: Double)] = [
        (100, 0), (110, 0.005), (120, 0.01), (130, 0.02), (140, 0.03), (150, 0.045), (160, 0.06), (170, 0.08), (180, 0.1),
    ]
    public static let coldBands: [(temperature: Double, factor: Double)] = [
        (5, 0), (0, 0.005), (-5, 0.01), (-10, 0.02),
    ]
    public static let coldStart = 5.0
    public static let driftHeatFactor = 0.02
    public static let zoneHeatFactor = 0.03
    public static let fadeHeatFactor = 0.03
    public static let fullSunRadiation = 800.0
    public static let fullSunBoost = 4.0
    public static let sunnyBoost = 2.0
    public static let hotSessionFactor = 0.02
    public static let adaptationWindowDays = 14
    public static let adaptationPerSession = 0.05
    public static let maxAdaptation = 0.4
    public static let windHeightFactor = 0.75
    public static let headwindCost = 0.0025
    public static let tailwindShare = 0.5
    public static let windEffectSeconds = 3.0
    public static let minimumHeatSeconds = 3
    public static let minimumHeadingMeters = 5.0
    public static let metersPerSecondToKmh = 3.6
}
