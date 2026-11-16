import Foundation
import GarminAPI
import TrainingCore

public enum MFITParser {
    private typealias C = MFITConstants

    static func program(_ dto: MFITProgramDTO, sessions: [Int64: MFITSessionDTO]) -> MFITProgram {
        let workouts = (dto.workouts ?? []).sorted { ($0.ordenacao ?? 0) < ($1.ordenacao ?? 0) }.enumerated().map { index, ref in
            MFITWorkout(
                id: ref.id,
                title: clean(ref.nome) ?? "",
                order: index,
                blocks: sessions[ref.id].map(blocks) ?? [],
                completions: (ref.feedback ?? []).compactMap(completion)
            )
        }
        return MFITProgram(id: dto.id, title: clean(dto.nome) ?? "", start: day(dto.dataInicio), end: day(dto.dataFim), teacherId: dto.idUser, workouts: workouts)
    }

    static func blocks(_ session: MFITSessionDTO) -> [StrengthBlock] {
        (session.exercs ?? []).sorted { ($0.order ?? 0) < ($1.order ?? 0) }.compactMap(block)
    }

    static func block(_ dto: MFITBlockDTO) -> StrengthBlock? {
        guard let main = dto.exercises?.first else { return nil }
        let series = (dto.exercises ?? []).flatMap { $0.series ?? [] }
        let texts = series.filter { $0.tipo == C.instructionType }.compactMap { clean($0.obs) }
        let combined = main.isCombinado == true || clean(main.name)?.lowercased() == C.combinedName
        let instruction = instruction(texts)
        let weight = series.filter { C.loadTypes.contains($0.tipo ?? -1) }.compactMap(\.carga).filter { $0 > 0 }.max()
        let exercises: [StrengthExercise]
        if combined {
            exercises = series.filter { $0.tipo == C.combinedItemType }.compactMap { serie in
                guard let name = clean(serie.exercicio?.name) else { return nil }
                return StrengthExercise(name: name, detail: nil, category: category(name: name, group: serie.exercicio?.exerciseGroup?.nome), exerciseKey: nil, reps: nil, seconds: nil)
            }
        } else {
            guard let name = clean(main.name) else { return nil }
            exercises = [StrengthExercise(
                name: name,
                detail: instruction,
                category: category(name: name, group: main.exerciseGroup?.nome),
                exerciseKey: nil,
                reps: instruction.flatMap { number(in: $0, pattern: C.repsPattern) },
                seconds: instruction.flatMap { number(in: $0, pattern: C.secondsPattern) }.map(Double.init),
                weight: weight
            )]
        }
        guard !exercises.isEmpty else { return nil }
        return StrengthBlock(
            exercises: exercises,
            sets: texts.lazy.compactMap { number(in: $0, pattern: C.setsPattern) }.first ?? C.defaultSets,
            restSeconds: rest(texts),
            note: combined ? instruction : nil
        )
    }

    public static func category(name: String, group: String?) -> String? {
        let lowered = name.lowercased()
        if let match = MFITCategoryConstants.byName.first(where: { entry in entry.keywords.contains { lowered.contains($0) } }) {
            return match.category
        }
        return clean(group).flatMap { MFITCategoryConstants.byGroup[$0.lowercased()] }
    }

    static func instruction(_ texts: [String]) -> String? {
        let own = texts.filter { first(in: $0, pattern: C.setsPattern) == nil }
        if !own.isEmpty { return own.joined(separator: " · ") }
        let derived = texts.lazy.map { text in
            text.replacingOccurrences(of: C.setsLeadPattern, with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: C.setsTailPattern, with: "", options: [.regularExpression, .caseInsensitive])
        }.compactMap(clean).first
        return derived
    }

    static func rest(_ texts: [String]) -> Double? {
        if texts.contains(where: { first(in: $0, pattern: C.noRestPattern) != nil }) { return nil }
        for text in texts {
            guard let groups = first(in: text, pattern: C.restPattern) else { continue }
            let values = [groups[0], groups[1]].compactMap { $0.flatMap(Double.init) }
            guard let top = values.max() else { continue }
            return groups[2].map { C.minuteWords.contains($0.lowercased()) } == true ? top * 60 : top
        }
        return C.defaultRestSeconds
    }

    static func number(in text: String, pattern: String) -> Int? {
        guard let groups = first(in: text, pattern: pattern) else { return nil }
        return [groups[0], groups.count > 1 ? groups[1] : nil].compactMap { $0.flatMap(Int.init) }.max()
    }

    static func first(in text: String, pattern: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<max(match.numberOfRanges, 2)).map { index in
            guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }

    static func completion(_ dto: MFITFeedbackDTO) -> MFITCompletion? {
        let iso = ISO8601DateFormatter()
        let start = dto.workoutStartTime.flatMap(iso.date(from:))
        let end = dto.workoutEndTime.flatMap(iso.date(from:))
        guard let reference = start ?? dto.dataExecucao.flatMap(iso.date(from:)) else { return nil }
        return MFITCompletion(day: Day.today(now: reference).iso, start: start, end: end, effort: dto.borgNota)
    }

    static func day(_ text: String?) -> String? {
        guard let text = clean(text) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: C.dateLocale)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = C.dateFormat
        guard let date = formatter.date(from: text) else { return nil }
        let parts = formatter.calendar.dateComponents(in: formatter.timeZone, from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return Day(year: year, month: month, day: day).iso
    }

    static func clean(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }
}
