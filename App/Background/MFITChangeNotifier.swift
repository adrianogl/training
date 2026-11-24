import CryptoKit
import Foundation
import MFIT

@MainActor final class MFITChangeNotifier {
    private typealias C = MFITChangeNotifierConstants

    private let scheduler: any NotificationScheduling
    private let schedule: StrengthSchedule
    private let calendar: Calendar
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling = NoticeInboxScheduler.standard, schedule: StrengthSchedule = StrengthSchedule(),
        calendar: Calendar = .current, now: @escaping () -> Date = { .now }
    ) {
        self.scheduler = scheduler
        self.schedule = schedule
        self.calendar = calendar
        self.now = now
    }

    func notify(_ changes: [MFITProgramChange], program: MFITProgram, teacher: String?, watch: TrainerChangeWatch, onlyPending: Bool = false) async {
        guard !changes.isEmpty else { return }
        let id = C.idPrefix + Self.version(program)
        if onlyPending, !(await scheduler.pending()).contains(id) { return }
        let text = MFITChangeNotifierText.body(changes, teacher: teacher, weekday: { schedule.weekday(for: $0.workout) }, watch: watch)
        await scheduler.schedule(
            id: id, title: MFITChangeNotifierText.title, text: text, link: C.deepLink,
            at: QuietHours.deliveryDate(now: now(), calendar: calendar)
        )
    }

    static func version(_ program: MFITProgram) -> String {
        let workouts = program.workouts.sorted { $0.id < $1.id }.map { MFITWorkout(id: $0.id, title: $0.title, order: $0.order, blocks: $0.blocks, completions: []) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(workouts)) ?? Data()
        let digest = SHA256.hash(data: Data(String(program.id).utf8) + data).map { String(format: "%02x", $0) }.joined()
        return String(digest.prefix(C.hashLength))
    }
}
