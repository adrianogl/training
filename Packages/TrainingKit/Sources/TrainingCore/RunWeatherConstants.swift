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
}
