import Foundation
import GarminAPI
import Insights
import MFIT
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerStrengthContextTests {
    private let monday = Day(iso: "2026-11-16")!

    private func block(_ category: String) -> StrengthBlock {
        StrengthBlock(exercises: [StrengthExercise(name: category, detail: nil, category: category, exerciseKey: nil, reps: 10, seconds: nil)], sets: 3, restSeconds: 60)
    }

    @Test func loadsMatchCatalogByExerciseName() {
        let records = [
            MFITLoadRecord(exercise: "Agachamento livre", key: MFITParser.exerciseKey("Agachamento livre"), day: "2026-11-10", loads: [55, 58], workoutId: 1),
            MFITLoadRecord(exercise: "Agachamento livre", key: MFITParser.exerciseKey("Agachamento livre"), day: "2026-11-12", loads: [60, 60, 60], workoutId: 2),
        ]
        let loads = TrainerStrengthContextBuilder.loads(records)
        #expect(loads["agachamento-livre"] == StrengthLoadRecord(weight: 60, completedAllSets: true))
        #expect(loads["leg-press"] == nil)
    }

    @Test func coveredPatternsComeFromTheMFITWeek() {
        let program = MFITProgram(id: 1, title: "Treino", start: "2026-11-13", end: "2026-12-18", workouts: [
            MFITWorkout(id: 10, title: "MMII", order: 0, blocks: [block("SQUAT"), block("CALF_RAISE")], completions: []),
        ])
        let schedule = StrengthSchedule(defaults: UserDefaults(suiteName: "strength-context-\(UUID())")!)
        let covered = TrainerStrengthContextBuilder.covered(program: program, schedule: schedule, week: monday)
        #expect(covered == [.squat, .calf])
    }

    @Test func prefsStoreKeepsPainSwapsAndKept() {
        let store = TrainerStrengthPrefsStore(defaults: UserDefaults(suiteName: "strength-prefs-\(UUID())")!)
        store.setPain([.knee])
        store.swap("dead-bug", to: "passaro-cao", on: "2026-11-18")
        store.setKeptOriginal(true, on: "2026-11-18")
        let prefs = store.load()
        #expect(prefs.pain == [.knee])
        #expect(prefs.painMarkedAt != nil)
        #expect(prefs.swaps["2026-11-18"] == ["dead-bug": "passaro-cao"])
        #expect(prefs.keptOriginal == ["2026-11-18"])
        store.setPain([])
        #expect(store.load().painMarkedAt == nil)
    }

    @MainActor
    @Test func adjustmentBannersRender() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let banners = VStack(spacing: 10) {
            TrainerStrengthBanner(adjustment: .lowReadiness(score: 42)) {}
            TrainerStrengthBanner(adjustment: .qualityDay(original: .lower)) {}
            TrainerStrengthBanner(adjustment: .raceWeek) {}
            TrainerStrengthBanner(adjustment: .pain([.calfAchilles])) {}
        }
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: banners.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
                try data.write(to: output.appending(path: "strength-banners-\(scheme).png"))
            }
        }
    }
}

@Suite struct TrainerStrengthStandaloneTests {
    @Test func standaloneStoreKeepsSessionsWithoutAPlan() {
        let store = TrainerStrengthStandaloneStore(defaults: UserDefaults(suiteName: "standalone-\(UUID())")!)
        #expect(store.load().isEmpty)
        let session = TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mobilidade e core", source: .trainer, intensity: .light, minutes: 25, place: .home)
        store.save([session])
        #expect(store.load() == [session])
    }

    @Test func externalKindDrivesTheQualityDayRuleWithoutAPlan() {
        let context = TrainerStrengthContextBuilder.context(
            day: Day(iso: "2026-11-18")!, plan: nil, externalKind: .threshold, readiness: nil, prefs: TrainerStrengthPrefs(),
            cache: StrengthProgramCache(program: nil, known: []), schedule: StrengthSchedule(defaults: UserDefaults(suiteName: "sched-\(UUID())")!)
        )
        #expect(context.runKind == .threshold)
        #expect(context.daysToRace == nil)
        #expect(context.isRecoveryWeek == false)
    }
}
