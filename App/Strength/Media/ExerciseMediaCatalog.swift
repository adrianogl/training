import Foundation
import Insights

struct ExerciseMediaCatalog: Sendable {
    static let shared: ExerciseMediaCatalog = {
        guard
            let url = Bundle.main.url(forResource: ExerciseMediaConstants.resourceName, withExtension: ExerciseMediaConstants.resourceExtension),
            let data = try? Data(contentsOf: url)
        else { return ExerciseMediaCatalog(data: Data()) }
        return ExerciseMediaCatalog(data: data)
    }()

    private let file: ExerciseMediaFile?

    init(data: Data) {
        file = try? JSONDecoder().decode(ExerciseMediaFile.self, from: data)
    }

    func key(forMFITName name: String, category: String?) -> ExerciseKey {
        if let id = file?.catalogIdByMFITName[Self.normalize(name)] { return .catalog(id) }
        return .mfit(Self.normalize(name))
    }

    func media(for key: ExerciseKey, fallback: MovementPattern?) -> [ExerciseMedia] {
        let pattern = Self.pattern(of: key) ?? fallback
        var items: [ExerciseMedia] = []
        if case .catalog(let id) = key {
            items = photos(forCatalogId: StrengthCatalog.canonicalId(id))
        }
        if let pattern { items.append(drawing(for: pattern)) }
        return items
    }

    func alternatives(for key: ExerciseKey, source: ExerciseMediaSource, excluding: Set<String>, limit: Int, fallback: MovementPattern?) -> [ExerciseMedia] {
        guard let file, limit > 0, source != .drawing, let pattern = Self.pattern(of: key) ?? fallback else { return [] }
        let own: CatalogExercise? = {
            if case .catalog(let id) = key { return StrengthCatalog.exercise(StrengthCatalog.canonicalId(id)) }
            return nil
        }()
        var blocked = excluding
        if let own { blocked.formUnion(photos(forCatalogId: own.id).map(\.id)) }
        let ownTokens: Set<String> = {
            if let own { return Self.tokens(own.name) }
            if case .mfit(let name) = key { return Self.tokens(name) }
            return []
        }()

        var seen = Set<String>()
        var ranked: [(media: ExerciseMedia, sharesEquipment: Bool, overlap: Int)] = []
        for id in file.mediaByCatalogId.keys.sorted() {
            guard StrengthCatalog.canonicalId(id) != own?.id, let candidate = StrengthCatalog.exercise(id), candidate.pattern == pattern else { continue }
            let sharesEquipment = own.map { $0.equipment == candidate.equipment } ?? false
            let overlap = ownTokens.intersection(Self.tokens(candidate.name)).count
            for media in photos(forCatalogId: id) where media.source == source {
                guard !blocked.contains(media.id), seen.insert(media.id).inserted else { continue }
                ranked.append((media, sharesEquipment, overlap))
            }
        }
        let ordered = ranked.enumerated().sorted { lhs, rhs in
            if lhs.element.sharesEquipment != rhs.element.sharesEquipment { return lhs.element.sharesEquipment }
            if lhs.element.overlap != rhs.element.overlap { return lhs.element.overlap > rhs.element.overlap }
            return lhs.offset < rhs.offset
        }
        return ordered.prefix(limit).map(\.element.media)
    }

    private static func pattern(of key: ExerciseKey) -> MovementPattern? {
        switch key {
        case .catalog(let id): StrengthCatalog.exercise(id)?.pattern
        case .mfit: nil
        }
    }

    private func photos(forCatalogId id: String) -> [ExerciseMedia] {
        guard let entries = file?.mediaByCatalogId[id] else { return [] }
        return entries.flatMap { entry -> [ExerciseMedia] in
            let groups: [[String]] = entry.source == .wger ? entry.frames.map { [$0] } : [entry.frames]
            return groups.compactMap { frames in
                guard let first = frames.first else { return nil }
                return ExerciseMedia(
                    id: "\(entry.source.rawValue):\(first)", source: entry.source, frames: frames,
                    equivalent: entry.equivalent, steps: entry.source == .wger ? [] : (entry.steps ?? []),
                    author: entry.author, license: entry.license, link: entry.link, pattern: nil
                )
            }
        }
    }

    private func drawing(for pattern: MovementPattern) -> ExerciseMedia {
        ExerciseMedia(
            id: "\(ExerciseMediaConstants.drawingIdPrefix):\(pattern.rawValue)", source: .drawing, frames: [], equivalent: false,
            steps: file?.stepsByPattern[pattern.rawValue]?.steps ?? [], author: nil, license: nil, link: nil, pattern: pattern
        )
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func tokens(_ text: String) -> Set<String> {
        Set(normalize(text).split(separator: " ").map(String.init).filter { $0.count > 2 })
    }
}
