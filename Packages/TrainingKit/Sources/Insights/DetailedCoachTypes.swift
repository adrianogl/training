public enum DetailedCoachPart: String, Sendable, Equatable, CaseIterable {
    case workout, context, history, positive, next

    public var title: String { DetailedCoachConstants.titles[self] ?? "" }
}

public struct DetailedCoachSection: Sendable, Equatable, Identifiable {
    public var part: DetailedCoachPart
    public var facts: [String]

    public var id: DetailedCoachPart { part }
    public var fallback: String { facts.joined(separator: " ") }

    public init(part: DetailedCoachPart, facts: [String]) {
        self.part = part
        self.facts = facts
    }
}
