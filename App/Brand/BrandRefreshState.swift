import CoreGraphics

struct BrandRefreshState: Equatable {
    private(set) var phase: BrandRefreshPhase = .idle
    private(set) var pull: CGFloat = 0
    let threshold: CGFloat

    init(threshold: CGFloat = BrandRefreshConstants.threshold) {
        self.threshold = threshold
    }

    var isActive: Bool { phase != .idle }

    var isArmed: Bool { phase == .pulling && pull >= threshold }

    var fraction: Double {
        switch phase {
        case .idle: 0
        case .pulling: threshold > 0 ? Double(min(max(pull / threshold, 0), 1)) : 0
        case .syncing, .done: 1
        }
    }

    mutating func update(overscroll: CGFloat, isInteracting: Bool) -> BrandRefreshEvent? {
        guard phase == .idle || phase == .pulling else { return nil }
        if isInteracting {
            pull = max(overscroll, 0)
            phase = pull > 0 ? .pulling : .idle
            return nil
        }
        guard phase == .pulling else { return nil }
        if pull >= threshold {
            phase = .syncing
            return .started
        }
        phase = .idle
        pull = 0
        return .cancelled
    }

    mutating func finish() {
        guard phase == .syncing else { return }
        phase = .done
    }

    mutating func settle() {
        phase = .idle
        pull = 0
    }
}
