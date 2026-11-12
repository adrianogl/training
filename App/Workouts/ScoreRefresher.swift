import Foundation

@MainActor final class ScoreRefresher {
    private let work: @Sendable () async -> Void
    private var current: Task<Void, Never>?

    init(work: @escaping @Sendable () async -> Void) {
        self.work = work
    }

    @discardableResult
    func refresh() -> Task<Void, Never> {
        let previous = current
        let work = work
        let task = Task {
            await previous?.value
            await work()
        }
        current = task
        return task
    }

    func finish() async {
        await current?.value
    }
}
