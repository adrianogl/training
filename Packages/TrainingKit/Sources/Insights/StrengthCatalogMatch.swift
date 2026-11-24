import Foundation

private typealias C = StrengthCatalogMatchConstants

public enum StrengthCatalogMatch {
    public static func exercise(named name: String) -> CatalogExercise? {
        let plain = normalized(name)
        let equipment = equipment(in: plain)
        let present = Set(plain.split(separator: " ").map(String.init))
        let modifiers = words(plain).intersection(C.modifiers)
        for alias in C.aliases {
            guard alias.phrases.contains(where: { Set($0.split(separator: " ").map(String.init)).isSubset(of: present) }),
                  alias.equipment.map({ equipment.contains($0) }) != false,
                  let exercise = StrengthCatalog.exercise(alias.id),
                  modifiers.isSubset(of: words(normalized(exercise.name))) else { continue }
            return exercise
        }
        return strict(plain, equipment: equipment)
    }

    static func strict(_ plain: String, equipment: Set<String>) -> CatalogExercise? {
        let target = words(plain)
        guard !target.isEmpty else { return nil }
        return StrengthCatalog.all.filter { candidate in
            let other = normalized(candidate.name)
            let otherWords = words(other)
            return target.isSubset(of: otherWords) && equipment.isSubset(of: self.equipment(in: other))
                && otherWords.intersection(C.modifiers).isSubset(of: target)
        }.min { $0.name.count < $1.name.count }
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR")).lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func equipment(in plain: String) -> Set<String> {
        Set(C.equipment.compactMap { key, terms in terms.contains { contains(plain, $0) } ? key : nil })
    }

    static func words(_ plain: String) -> Set<String> {
        let equipmentTerms = Set(C.equipment.values.flatMap { $0 })
        return Set(plain.split(separator: " ").map(String.init)
            .filter { $0.count >= C.minimumWordLength && !C.stopwords.contains($0) && !equipmentTerms.contains($0) && !C.neutralWords.contains($0) }
            .map { C.synonyms[$0] ?? stem($0) })
    }

    static func stem(_ word: String) -> String {
        word.count > 4 && word.hasSuffix("s") ? String(word.dropLast()) : word
    }

    static func contains(_ plain: String, _ phrase: String) -> Bool {
        (" " + plain + " ").contains(" " + phrase + " ")
    }
}
