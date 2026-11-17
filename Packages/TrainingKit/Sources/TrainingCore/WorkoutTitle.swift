import Foundation

public enum WorkoutTitle {
    static let weekdays = ["seg", "ter", "qua", "qui", "sex", "sáb", "sab", "dom"]

    public static func clean(_ title: String) -> String {
        let words = title.split(separator: " ", omittingEmptySubsequences: false)
        guard words.count > 2, words[0].compare(words[1], options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame else { return title }
        return words.dropFirst().joined(separator: " ")
    }

    public static func comparisonKey(_ title: String) -> String {
        var words = clean(title).lowercased().split(separator: " ").map(String.init)
        if let weekday = words.firstIndex(where: weekdays.contains) {
            words.removeSubrange(weekday...)
        } else if let last = words.last, words.count > 1, weekdays.contains(where: { $0.hasPrefix(last) && $0 != last }) {
            words.removeLast()
        }
        return words.joined(separator: " ")
    }
}
