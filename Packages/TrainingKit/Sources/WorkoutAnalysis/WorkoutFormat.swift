import Foundation

public enum WorkoutFormat {
    public static let locale = Locale(identifier: "pt_BR")

    public static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    public static func kilometers(_ meters: Double) -> String {
        (meters / AnalysisConstants.metersPerKilometer).formatted(.number.precision(.fractionLength(1)).locale(locale))
    }
}
