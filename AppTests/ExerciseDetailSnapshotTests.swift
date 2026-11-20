import Foundation
import Insights
import SwiftUI
import Testing
import UIKit
@testable import trAIning

@MainActor
@Suite(.serialized) struct ExerciseDetailSnapshotTests {
    private static let goblet = ExerciseDetailInput(
        key: .catalog("SQUAT/GOBLET_SQUAT"), name: "Agachamento goblet", dose: "3 × 10", load: "16 kg", suggestedLoad: nil,
        pattern: .squat, mfitNote: nil, workoutDay: "2026-11-20", rest: "descanso 60 s"
    )

    private static let singleLegDeadlift = ExerciseDetailInput(
        key: .catalog("DEADLIFT/SINGLE_LEG_ROMANIAN_DEADLIFT_WITH_DUMBBELL"), name: "Terra com uma perna", dose: "3 × 10 cada", load: "8 kg",
        suggestedLoad: SuggestedLoad(weight: 8, baseId: "DEADLIFT/ROMANIAN_DEADLIFT", baseWeight: 40, baseDay: "2026-11-14"),
        pattern: .hinge, mfitNote: nil, workoutDay: "2026-11-20", rest: "descanso 60 s"
    )

    private struct Stores {
        let feedback: ExerciseFeedbackStore
        let notes: ExerciseNotesStore
        let folder: URL
    }

    private func makeStores() -> Stores {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return Stores(
            feedback: ExerciseFeedbackStore(url: folder.appending(path: "feedback.json")),
            notes: ExerciseNotesStore(url: folder.appending(path: "notes.json"), stamps: nil),
            folder: folder
        )
    }

    private func model(_ input: ExerciseDetailInput = goblet, stores: Stores, now: Date = Date(timeIntervalSince1970: 1_795_000_000)) -> ExerciseDetailModel {
        ExerciseDetailModel(input: input, feedback: stores.feedback, notes: stores.notes, now: { now })
    }

    @Test func does_not_match_moves_choice_and_saves_before_closing() throws {
        let stores = makeStores()
        let detail = model(stores: stores)
        let evaluated = try #require(detail.current)
        detail.markDoesNotMatch()
        #expect(detail.panel == .alternatives)
        #expect(detail.alternativeSource == .freeExerciseDb)
        #expect(!detail.alternatives.isEmpty && detail.alternatives.count <= 3)
        #expect(detail.alternatives.allSatisfy { $0.source == .freeExerciseDb })
        let choice = try #require(detail.alternatives.first)

        detail.choose(choice)

        let saved = try #require(stores.feedback.all().first)
        #expect(stores.feedback.all().count == 1)
        #expect(saved.verdict == .doesNotMatch)
        #expect(saved.mediaId == evaluated.id)
        #expect(saved.chosenMediaId == choice.id)
        #expect(saved.workoutDay == "2026-11-20")
        #expect(detail.panel == .question)
        #expect(detail.media.first?.id == choice.id)
        #expect(detail.currentId == choice.id)
        #expect(stores.feedback.preferredMediaId(for: Self.goblet.key) == choice.id)
        #expect(ExerciseDetailModel(input: Self.goblet, feedback: stores.feedback, notes: stores.notes).media.first?.id == choice.id)
    }

    @Test func failed_save_keeps_alternatives_open() throws {
        let stores = makeStores()
        let blocker = stores.folder.appending(path: "blocker")
        try Data().write(to: blocker)
        let broken = Stores(feedback: ExerciseFeedbackStore(url: blocker.appending(path: "feedback.json")), notes: stores.notes, folder: stores.folder)
        let detail = model(stores: broken)
        detail.markDoesNotMatch()
        let choice = try #require(detail.alternatives.first)
        detail.choose(choice)
        #expect(detail.panel == .alternatives)
        #expect(detail.feedbackFailed)
        #expect(detail.media.first?.id != choice.id)
    }

    @Test func wger_search_swaps_alternatives() {
        let stores = makeStores()
        let detail = model(stores: stores)
        detail.markDoesNotMatch()
        detail.searchWger()
        #expect(detail.alternativeSource == .wger)
        #expect(detail.alternatives.allSatisfy { $0.source == .wger })
    }

    @Test func undo_supersedes_choice_without_deleting() throws {
        let stores = makeStores()
        let detail = model(stores: stores)
        let original = try #require(detail.current)
        detail.markDoesNotMatch()
        let choice = try #require(detail.alternatives.first)
        detail.choose(choice)
        detail.undo()
        let entries = stores.feedback.all()
        #expect(entries.count == 2)
        #expect(entries.contains { $0.undoes == entries.first { $0.chosenMediaId == choice.id }?.id })
        #expect(stores.feedback.preferredMediaId(for: Self.goblet.key) == nil)
        #expect(detail.media.first?.id == original.id)
        #expect(detail.verdict(for: original) == .unrated)
    }

    @Test func use_drawing_saves_then_note_updates_same_entry() throws {
        let stores = makeStores()
        let detail = model(stores: stores)
        detail.markDoesNotMatch()
        detail.useDrawing()
        #expect(detail.current?.source == .drawing)
        #expect(detail.panel == .drawingNote)
        #expect(stores.feedback.all().first?.noneMatched == true)
        detail.suggestion = "Peso no peito, não nas costas."
        detail.saveSuggestion()
        #expect(stores.feedback.all().count == 1)
        #expect(stores.feedback.all().first?.note == "Peso no peito, não nas costas.")
    }

    @Test func failed_note_save_keeps_text() throws {
        let stores = makeStores()
        let blocker = stores.folder.appending(path: "blocker")
        try Data().write(to: blocker)
        let broken = Stores(feedback: stores.feedback, notes: ExerciseNotesStore(url: blocker.appending(path: "notes.json"), stamps: nil), folder: stores.folder)
        let detail = model(stores: broken)
        detail.addNote()
        detail.draft?.text = "Pausa embaixo."
        detail.saveDraft()
        #expect(detail.notesFailed)
        #expect(detail.draft?.text == "Pausa embaixo.")
    }

    @Test func carousel_first_and_second_image() async throws {
        let stores = makeStores()
        let first = model(stores: stores)
        try await snapshot(ExerciseDetailScreen(model: first), "carrossel-1")
        let second = model(stores: stores)
        second.currentId = second.media[1].id
        try await snapshot(ExerciseDetailScreen(model: second), "carrossel-2")
    }

    @Test func after_matches() async throws {
        let stores = makeStores()
        let detail = model(stores: stores)
        detail.markMatches()
        try await snapshot(ExerciseDetailScreen(model: detail), "corresponde")
    }

    @Test func alternatives_open() async throws {
        let stores = makeStores()
        let detail = model(stores: stores)
        detail.markDoesNotMatch()
        try await snapshot(ExerciseDetailScreen(model: detail), "alternativas")
        detail.choose(try #require(detail.alternatives.first))
        try await snapshot(ExerciseDetailScreen(model: detail), "alternativa-escolhida")
    }

    @Test func drawing_with_field() async throws {
        let stores = makeStores()
        let detail = model(stores: stores)
        detail.markDoesNotMatch()
        detail.useDrawing()
        detail.suggestion = "Peso no peito, não nas costas."
        try await snapshot(ExerciseDetailScreen(model: detail), "desenho-com-campo")
    }

    @Test func notes_with_mfit_observation() async throws {
        let stores = makeStores()
        let input = ExerciseDetailInput(
            key: Self.goblet.key, name: Self.goblet.name, dose: Self.goblet.dose, load: Self.goblet.load, suggestedLoad: nil,
            pattern: .squat, mfitNote: "Descer em 3 s.", workoutDay: nil, rest: Self.goblet.rest
        )
        try stores.notes.save(ExerciseNote(id: UUID(), exercise: input.key, text: "Joelho acompanha a ponta do pé; não deixar fechar na subida.", createdAt: Date(timeIntervalSince1970: 1_794_500_000), updatedAt: Date(timeIntervalSince1970: 1_794_500_000), deleted: false))
        let detail = model(input, stores: stores)
        try await snapshot(ExerciseDetailScreen(model: detail), "observacoes")
        detail.addNote()
        detail.draft?.text = "Pausa de 1 s embaixo nas duas últimas séries."
        try await snapshot(ExerciseDetailScreen(model: detail), "observacao-editor")
    }

    @Test func suggested_load_block() async throws {
        let stores = makeStores()
        try await snapshot(ExerciseDetailScreen(model: model(Self.singleLegDeadlift, stores: stores)), "carga-sugerida")
    }

    @Test func workout_rows_with_thumbnails() async throws {
        let exercises = [
            GeneratedExercise(exerciseId: "SQUAT/GOBLET_SQUAT", name: "Agachamento goblet", category: "SQUAT", exerciseName: "GOBLET_SQUAT", sets: 3, reps: 10, seconds: nil, restSeconds: 60, weight: 16, perSide: false),
            GeneratedExercise(exerciseId: "DEADLIFT/SINGLE_LEG_ROMANIAN_DEADLIFT_WITH_DUMBBELL", name: "Terra com uma perna", category: "DEADLIFT", exerciseName: nil, sets: 3, reps: 10, seconds: nil, restSeconds: 60, weight: 8, perSide: true, suggestedLoad: Self.singleLegDeadlift.suggestedLoad),
            GeneratedExercise(exerciseId: "CALF_RAISE/SINGLE_LEG_STANDING_CALF_RAISE", name: "Panturrilha unilateral", category: "CALF_RAISE", exerciseName: nil, sets: 3, reps: 12, seconds: nil, restSeconds: 45, weight: nil, perSide: true),
        ]
        let rows = VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                if index > 0 { Divider().overlay(BrandColors.line) }
                TrainerExerciseRow(exercise: exercise, onOpen: {}, onSwap: {}).padding(.vertical, 9)
            }
        }
        .brandCard()
        try await snapshot(rows.padding(16), "lista-treinador", height: 300)
    }

    private func snapshot(_ view: some View, _ name: String, height: CGFloat = 1700) async throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let stores = makeStores()
        let root = view
            .environment(\.exerciseFeedbackStore, stores.feedback)
            .environment(\.exerciseNotesStore, stores.notes)
            .frame(width: 390, height: height, alignment: .top)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let host = UIHostingController(rootView: root)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: height)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(900))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try FileManager.default.createDirectory(at: URL(filePath: dir), withIntermediateDirectories: true)
        try image.pngData()?.write(to: URL(filePath: dir).appending(path: "\(name).png"))
        window.isHidden = true
    }
}
