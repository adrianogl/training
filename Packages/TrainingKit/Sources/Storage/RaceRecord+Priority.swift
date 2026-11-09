extension RaceRecord {
    public var priorityLevel: RacePriority {
        get { RacePriority(rawValue: priority) ?? .c }
        set { priority = newValue.rawValue }
    }
}
