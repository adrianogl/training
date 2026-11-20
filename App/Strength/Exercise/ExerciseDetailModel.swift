import Foundation
import Insights
import Observation

@MainActor @Observable final class ExerciseDetailModel {
    let input: ExerciseDetailInput
    @ObservationIgnored private let feedbackStore: ExerciseFeedbackStore
    @ObservationIgnored private let notesStore: ExerciseNotesStore
    @ObservationIgnored private let catalog: ExerciseMediaCatalog
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var evaluatedId: String?
    @ObservationIgnored private var noneEntry: ExerciseFeedback?

    private(set) var media: [ExerciseMedia] = []
    var currentId: String? {
        didSet {
            guard currentId != oldValue else { return }
            if panel == .alternatives { panel = .question }
            if panel == .drawingNote, currentId != drawing?.id { panel = .question }
            suggestionSaved = false
            feedbackFailed = false
        }
    }
    private(set) var panel: ExerciseFeedbackPanel = .question
    private(set) var alternativeSource: ExerciseMediaSource = .freeExerciseDb
    private(set) var alternatives: [ExerciseMedia] = []
    var suggestion = ""
    private(set) var suggestionSaved = false
    private(set) var feedbackFailed = false
    private(set) var notes: [ExerciseNote] = []
    var draft: ExerciseNoteDraft?
    private(set) var notesFailed = false
    private var revision = 0

    init(input: ExerciseDetailInput, feedback: ExerciseFeedbackStore, notes: ExerciseNotesStore, catalog: ExerciseMediaCatalog = .shared, now: @escaping () -> Date = { .now }) {
        self.input = input
        feedbackStore = feedback
        notesStore = notes
        self.catalog = catalog
        self.now = now
        media = orderedMedia()
        currentId = media.first?.id
        self.notes = notes.notes(for: input.key)
    }

    var current: ExerciseMedia? {
        media.first { $0.id == currentId } ?? media.first
    }

    var currentIndex: Int {
        media.firstIndex { $0.id == current?.id } ?? 0
    }

    var drawing: ExerciseMedia? {
        media.first { $0.source == .drawing }
    }

    var pattern: MovementPattern? {
        if case .catalog(let id) = input.key, let pattern = StrengthCatalog.exercise(id)?.pattern { return pattern }
        return input.pattern
    }

    var steps: [String] {
        if let steps = current?.steps, !steps.isEmpty { return steps }
        return (current?.pattern ?? pattern).map(catalog.steps(for:)) ?? []
    }

    var catalogExercise: CatalogExercise? {
        if case .catalog(let id) = input.key { return StrengthCatalog.exercise(id) }
        return nil
    }

    var isPerHand: Bool {
        guard let suggestion = input.suggestedLoad, let exercise = catalogExercise else { return false }
        return StrengthLoadSuggestion.isPerHand(suggestion, for: exercise)
    }

    func alternativeName(_ media: ExerciseMedia) -> String {
        catalog.exerciseName(forMediaId: media.id) ?? input.name
    }

    func verdict(for media: ExerciseMedia) -> ExerciseVerdictState {
        _ = revision
        if let choice = feedbackStore.preferredChoice(for: input.key), choice.chosenMediaId == media.id { return .chosen(choice) }
        guard let entry = feedbackStore.latest(for: input.key, mediaId: media.id), entry.undoes == nil else { return .unrated }
        return entry.verdict == .matches ? .matched(entry) : .rejected(entry)
    }

    func markMatches() {
        guard let current else { return }
        _ = record(entry(for: current, verdict: .matches))
    }

    func markDoesNotMatch() {
        guard let current else { return }
        evaluatedId = current.id
        loadAlternatives(.freeExerciseDb)
        panel = .alternatives
    }

    func searchWger() {
        loadAlternatives(.wger)
    }

    func choose(_ alternative: ExerciseMedia) {
        guard let evaluated = evaluatedMedia else { return }
        var choice = entry(for: evaluated, verdict: .doesNotMatch)
        choice.chosenMediaId = alternative.id
        guard record(choice) else { return }
        panel = .question
        media = orderedMedia()
        currentId = alternative.id
    }

    func useDrawing() {
        guard let evaluated = evaluatedMedia, let drawing else { return }
        var none = entry(for: evaluated, verdict: .doesNotMatch)
        none.noneMatched = true
        guard record(none) else { return }
        noneEntry = none
        suggestion = ""
        currentId = drawing.id
        panel = .drawingNote
    }

    func saveSuggestion() {
        guard var none = noneEntry else { return }
        let text = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        none.note = text.isEmpty ? nil : String(text.prefix(ExerciseNotesConstants.maxNoteLength))
        none.updatedAt = max(now(), none.updatedAt.addingTimeInterval(ExerciseDetailConstants.editTouchSeconds))
        guard record(none) else { return }
        noneEntry = nil
        suggestion = ""
        panel = .question
        suggestionSaved = true
    }

    func undo() {
        guard let current else { return }
        let target: ExerciseFeedback
        switch verdict(for: current) {
        case .unrated: return
        case .matched(let entry), .chosen(let entry), .rejected(let entry): target = entry
        }
        let stamp = now()
        let reverting = ExerciseFeedback(
            id: UUID(), exercise: input.key, exerciseName: input.name, mediaId: target.mediaId, verdict: target.verdict,
            chosenMediaId: nil, noneMatched: false, note: nil, createdAt: stamp,
            updatedAt: max(stamp, target.updatedAt.addingTimeInterval(ExerciseDetailConstants.editTouchSeconds)),
            workoutDay: input.workoutDay, status: .resolved, resolution: nil, resolvedIn: nil, undoes: target.id
        )
        guard record(reverting) else { return }
        guard target.chosenMediaId != nil else { return }
        media = orderedMedia()
        currentId = media.contains { $0.id == target.mediaId } ? target.mediaId : media.first?.id
    }

    func addNote() {
        notesFailed = false
        draft = ExerciseNoteDraft(id: nil, text: "")
    }

    func edit(_ note: ExerciseNote) {
        notesFailed = false
        draft = ExerciseNoteDraft(id: note.id, text: note.text)
    }

    func cancelDraft() {
        notesFailed = false
        draft = nil
    }

    func saveDraft() {
        guard let draft else { return }
        let text = String(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ExerciseNotesConstants.maxNoteLength))
        guard !text.isEmpty else { return cancelDraft() }
        let stamp = now()
        let note: ExerciseNote
        if let id = draft.id, let existing = notes.first(where: { $0.id == id }) {
            var edited = existing
            edited.text = text
            edited.updatedAt = max(stamp, existing.updatedAt.addingTimeInterval(ExerciseDetailConstants.editTouchSeconds))
            note = edited
        } else {
            note = ExerciseNote(id: UUID(), exercise: input.key, text: text, createdAt: stamp, updatedAt: stamp, deleted: false)
        }
        do {
            try notesStore.save(note)
        } catch {
            notesFailed = true
            return
        }
        notesFailed = false
        self.draft = nil
        notes = notesStore.notes(for: input.key)
    }

    func delete(_ note: ExerciseNote) {
        do {
            try notesStore.delete(note.id, at: now())
        } catch {
            notesFailed = true
            return
        }
        notesFailed = false
        notes = notesStore.notes(for: input.key)
    }

    private var evaluatedMedia: ExerciseMedia? {
        media.first { $0.id == evaluatedId }
    }

    private func loadAlternatives(_ source: ExerciseMediaSource) {
        alternativeSource = source
        feedbackFailed = false
        alternatives = catalog.alternatives(
            for: input.key, source: source, excluding: Set(media.map(\.id)), limit: ExerciseDetailConstants.alternativesLimit, fallback: input.pattern
        )
    }

    private func entry(for media: ExerciseMedia, verdict: ExerciseFeedbackVerdict) -> ExerciseFeedback {
        let stamp = now()
        return ExerciseFeedback(
            id: UUID(), exercise: input.key, exerciseName: input.name, mediaId: media.id, verdict: verdict,
            chosenMediaId: nil, noneMatched: false, note: nil, createdAt: stamp, updatedAt: stamp,
            workoutDay: input.workoutDay, status: .pending, resolution: nil, resolvedIn: nil
        )
    }

    private func record(_ entry: ExerciseFeedback) -> Bool {
        do {
            try feedbackStore.save(entry)
        } catch {
            feedbackFailed = true
            return false
        }
        feedbackFailed = false
        revision += 1
        return true
    }

    private func orderedMedia() -> [ExerciseMedia] {
        var items = catalog.media(for: input.key, fallback: input.pattern)
        guard let preferred = feedbackStore.preferredMediaId(for: input.key) else { return items }
        if let index = items.firstIndex(where: { $0.id == preferred }) {
            items.insert(items.remove(at: index), at: 0)
        } else if let chosen = catalog.media(withId: preferred) {
            items.insert(chosen, at: 0)
        }
        return items
    }
}
