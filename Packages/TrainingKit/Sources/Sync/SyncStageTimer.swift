import Foundation

struct SyncStageTimer {
    private let clock = ContinuousClock()
    private var mark: ContinuousClock.Instant

    init() {
        mark = clock.now
    }

    mutating func lap(_ stage: String, items: Int = 0) {
        let now = clock.now
        let milliseconds = Int((now - mark) / .milliseconds(1))
        mark = now
        SyncConstants.timingLogger.info("etapa \(stage, privacy: .public): \(milliseconds, privacy: .public) ms, \(items, privacy: .public) itens")
    }
}
