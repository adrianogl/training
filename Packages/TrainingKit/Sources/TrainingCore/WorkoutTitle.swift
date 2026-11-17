import Foundation

public enum WorkoutTitle {
    public static func clean(_ title: String) -> String {
        let words = title.split(separator: " ", omittingEmptySubsequences: false)
        guard words.count > 2, words[0].compare(words[1], options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame else { return title }
        return words.dropFirst().joined(separator: " ")
    }
}
