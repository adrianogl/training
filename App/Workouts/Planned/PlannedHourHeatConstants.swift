import CoreGraphics

enum PlannedHourHeatConstants {
    static let minimumSavedSeconds = 3
    static let warmSeconds = 5
    static let hotSeconds = 12
    static let extraFormat = "+%d s"
    static let noExtra = "0 s"
    static let paceRowFormat = "Principal às %dh"
    static let paceExtraWidth: CGFloat = 44
    static let paceValueFormat = "%@/km"
}
