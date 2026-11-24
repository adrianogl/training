import Foundation
import GarminAPI
import MFIT
import Storage
import Testing
import TrainingCore
@testable import trAIning

private struct NoKeyStore: APIKeyStore {
    func read() throws -> String? { nil }
    func save(_ key: String) throws {}
    func delete() throws {}
}

@MainActor @Suite struct MFITChangeNotifierTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: hour))!
    }

    private func workout(_ id: Int64, title: String, order: Int, reps: Int = 10, done: [String] = []) -> MFITWorkout {
        let squat = StrengthExercise(name: "Agachamento", detail: nil, category: "SQUAT", exerciseKey: nil, reps: reps, seconds: nil, weight: 20)
        return MFITWorkout(
            id: id, title: title, order: order, blocks: [StrengthBlock(exercises: [squat], sets: 3, restSeconds: 60)],
            completions: done.map { MFITCompletion(day: $0, start: nil, end: nil, effort: nil) }
        )
    }

    private func program(_ workouts: [MFITWorkout]) -> MFITProgram {
        MFITProgram(id: 9, title: "Programa", start: "2026-11-01", end: nil, teacherId: 3, workouts: workouts)
    }

    private func store() -> StrengthProgramStore {
        StrengthProgramStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("mfit-change-\(UUID()).json"))
    }

    private func schedule() -> StrengthSchedule {
        StrengthSchedule(defaults: UserDefaults(suiteName: "mfit-change-\(UUID())")!)
    }

    @Test func firstLoadDoesNotCountAsAChange() {
        let store = store()
        #expect(store.refresh(with: program([workout(1, title: "Treino A", order: 0)])).changes.isEmpty)
        #expect(store.load().program != nil)
    }

    @Test func detectsNewRemovedAndChangedWorkouts() {
        let store = store()
        store.refresh(with: program([workout(1, title: "Treino A", order: 0), workout(2, title: "Treino B", order: 1)]))
        let update = store.refresh(with: program([workout(1, title: "Treino A", order: 0, reps: 12), workout(3, title: "Treino C", order: 2)]))
        #expect(update.changes.map(\.kind) == [.changed, .added, .removed])
        #expect(update.changes.map(\.workout.id) == [1, 3, 2])
    }

    @Test func finishedWorkoutsAreNotAChange() {
        let store = store()
        store.refresh(with: program([workout(1, title: "Treino A", order: 0)]))
        #expect(store.refresh(with: program([workout(1, title: "Treino A", order: 0, done: ["2026-11-19"])])).changes.isEmpty)
    }

    @Test func newProgramAfterAnEndedOneIsAChange() {
        let store = store()
        store.refresh(with: program([workout(1, title: "Treino A", order: 0)]))
        _ = store.clearProgram()
        #expect(store.refresh(with: program([workout(4, title: "Treino D", order: 0)])).changes.map(\.kind) == [.added])
    }

    @Test func pushesTheTeacherAndTheWeekday() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(hour: 10)
        let notifier = MFITChangeNotifier(scheduler: scheduler, schedule: schedule(), calendar: calendar, now: { now })
        let changed = workout(2, title: "Corpo inteiro B", order: 2)
        let current = program([changed])
        await notifier.notify([MFITProgramChange(kind: .changed, workout: changed)], program: current, teacher: "Pedro Vargas", watch: .pending)
        let id = "mfit-change-" + MFITChangeNotifier.version(current)
        #expect(await scheduler.delivered == [id])
        #expect(await scheduler.headers[id]?.title == "Treino novo no MFIT")
        #expect(await scheduler.headers[id]?.link == "training://treinador/forca")
        #expect(await scheduler.scheduled[id]?.text == "Pedro Vargas mudou o treino de sexta: Corpo inteiro B. Falta enviar ao relógio.")
    }

    @Test func severalChangesWithoutTeacherWaitForMorning() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(hour: 23)
        let notifier = MFITChangeNotifier(scheduler: scheduler, schedule: schedule(), calendar: calendar, now: { now })
        let changes = [workout(1, title: "Treino A", order: 0), workout(2, title: "Treino B", order: 1)].map { MFITProgramChange(kind: .added, workout: $0) }
        let current = program(changes.map(\.workout))
        await notifier.notify(changes, program: current, teacher: nil, watch: .current)
        let id = "mfit-change-" + MFITChangeNotifier.version(current)
        #expect(await scheduler.scheduled[id]?.text == "O professor mudou 2 treinos. Já está no relógio.")
        #expect(await scheduler.scheduled[id]?.at == calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 7)))
    }

    @Test func versionIgnoresCompletions() {
        let before = program([workout(1, title: "Treino A", order: 0)])
        let after = program([workout(1, title: "Treino A", order: 0, done: ["2026-11-19"])])
        #expect(MFITChangeNotifier.version(before) == MFITChangeNotifier.version(after))
        #expect(MFITChangeNotifier.version(before) != MFITChangeNotifier.version(program([workout(1, title: "Treino A", order: 0, reps: 12)])))
    }

    @Test func watchRewriteOnlyTouchesAPushThatHasNotGoneOut() async {
        let scheduler = FakeNotificationScheduler()
        let changed = workout(2, title: "Corpo inteiro B", order: 2)
        let current = program([changed])
        let changes = [MFITProgramChange(kind: .changed, workout: changed)]
        let id = "mfit-change-" + MFITChangeNotifier.version(current)
        let day = MFITChangeNotifier(scheduler: scheduler, schedule: schedule(), calendar: calendar, now: { date(hour: 10) })
        await day.notify(changes, program: current, teacher: "Pedro", watch: .none)
        await day.notify(changes, program: current, teacher: "Pedro", watch: .current, onlyPending: true)
        #expect(await scheduler.delivered == [id])
        #expect(await scheduler.scheduled[id]?.text == "Pedro mudou o treino de sexta: Corpo inteiro B.")
        let night = MFITChangeNotifier(scheduler: scheduler, schedule: schedule(), calendar: calendar, now: { date(hour: 23) })
        await night.notify(changes, program: current, teacher: "Pedro", watch: .none)
        await night.notify(changes, program: current, teacher: "Pedro", watch: .current, onlyPending: true)
        #expect(await scheduler.scheduled[id]?.text == "Pedro mudou o treino de sexta: Corpo inteiro B. Já está no relógio.")
    }

    @Test func cancelledBackgroundSendStillSchedulesTheNotice() async throws {
        let model = AppModel(
            container: try TrainingSchema.container(inMemory: true), keyStore: NoKeyStore(), remoteKeyStore: MemoryKeyStore(),
            autoSyncEnabled: false, readinessComplete: true, readinessDay: Day(year: 2026, month: 11, day: 20),
            today: { Day(year: 2026, month: 11, day: 20) }
        )
        let scheduler = FakeNotificationScheduler()
        let now = date(hour: 23)
        model.mfitChanges = MFITChangeNotifier(scheduler: scheduler, schedule: schedule(), calendar: calendar, now: { now })
        let changed = workout(2, title: "Corpo inteiro B", order: 2)
        let current = program([changed])
        let update = MFITProgramUpdate(
            cache: StrengthProgramCache(program: current, known: current.workouts), changes: [MFITProgramChange(kind: .changed, workout: changed)]
        )
        let send = Task { await model.backgroundSend(mfit: update) }
        send.cancel()
        await send.value
        #expect(await scheduler.scheduled["mfit-change-" + MFITChangeNotifier.version(current)] != nil)
    }
}
