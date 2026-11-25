import Foundation

public enum TrainerDayAdjustConstants {
    public static let minimumChangeSeconds = 3
    public static let activeKinds: Set<TrainerStepKind> = [.work, .steady]
}
