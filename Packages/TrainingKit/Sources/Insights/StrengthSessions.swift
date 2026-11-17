public enum StrengthSessions {
    public static func merge(mfit: [TrainerStrengthSession], into current: [TrainerStrengthSession]) -> [TrainerStrengthSession] {
        let tagged = mfit.map { session -> TrainerStrengthSession in
            var copy = session
            copy.source = .mfit
            return copy
        }
        return (current.filter { $0.source == .trainer } + tagged).sorted { $0.weekday < $1.weekday }
    }

    public static func sameMFIT(_ mfit: [TrainerStrengthSession], _ current: [TrainerStrengthSession]) -> Bool {
        let key: (TrainerStrengthSession) -> String = { "\($0.weekday)|\($0.group.rawValue)|\($0.legLoad.rawValue)|\($0.name)" }
        return mfit.map(key).sorted() == current.filter { $0.source == .mfit }.map(key).sorted()
    }

    public static func legLoad(group: TrainerStrengthGroup, intensity: TrainerStrengthIntensity) -> TrainerStrengthLoad {
        switch group {
        case .lower: intensity == .light ? .light : .heavy
        case .fullBody: intensity == .heavy ? .heavy : .light
        case .upper, .core: .light
        }
    }
}

public enum StrengthSuggestion {
    public static func suggest(_ sessions: [TrainerStrengthSession], structure: [Int: TrainerDayKind]) -> [TrainerStrengthSession] {
        let complementing = sessions.contains { $0.source == .mfit }
        var legsTaken = sessions.contains { $0.source == .mfit && $0.legLoad == .heavy }
        return sessions.sorted { $0.weekday < $1.weekday }.map { session in
            guard session.source == .trainer else { return session }
            var copy = session
            let (group, intensity) = focus(for: session.weekday, structure: structure, complementing: complementing, legsTaken: legsTaken)
            if StrengthSessions.legLoad(group: group, intensity: intensity) == .heavy { legsTaken = true }
            copy.group = group
            copy.intensity = intensity
            copy.legLoad = StrengthSessions.legLoad(group: group, intensity: intensity)
            if group == .core {
                copy.minutes = StrengthSessionConstants.mobilityMinutes
            }
            return copy
        }
    }

    private static func focus(for weekday: Int, structure: [Int: TrainerDayKind], complementing: Bool, legsTaken: Bool) -> (TrainerStrengthGroup, TrainerStrengthIntensity) {
        if complementing { return (.core, .light) }
        if isQuality(weekday, structure) || isQuality(offset(weekday, 1), structure) { return (.core, .light) }
        if isQuality(offset(weekday, 2), structure) || legsTaken { return (.upper, .moderate) }
        return (.lower, .heavy)
    }

    static func isQuality(_ weekday: Int, _ structure: [Int: TrainerDayKind]) -> Bool {
        structure[weekday].map(StrengthSessionConstants.qualityKinds.contains) ?? false
    }

    static func offset(_ weekday: Int, _ days: Int) -> Int {
        (weekday - 1 + days) % StrengthSessionConstants.weekdays + 1
    }
}
