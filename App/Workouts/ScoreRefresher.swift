import Foundation
import Observation

@MainActor @Observable final class ScoreRefresher {
    @ObservationIgnored private let work: @Sendable () async -> Bool
    @ObservationIgnored private var current: Task<Void, Never>?
    private(set) var revision = 0

    init(work: @escaping @Sendable () async -> Bool) {
        self.work = work
    }

    @discardableResult
    func refresh() -> Task<Void, Never> {
        let previous = current
        let work = work
        let task = Task {
            await previous?.value
            if await work() { revision += 1 }
        }
        current = task
        return task
    }

    func finish() async {
        await current?.value
    }
}
