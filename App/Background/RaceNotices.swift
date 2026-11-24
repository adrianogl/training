import Foundation
import GarminAPI
import Storage
import SwiftData
import TrainingCore

@MainActor enum RaceNotices {
    private typealias C = RaceNoticeConstants

    static func refresh(container: ModelContainer, client: GarminAccountClient?, scheduler: any NotificationScheduling = NoticeInboxScheduler.standard, now: Date = .now) async {
        let today = Day.today(now: now)
        let last = today.adding(days: C.lookAheadDays).iso
        let first = today.iso
        let descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil && $0.day >= first && $0.day <= last && $0.resultActivityId == nil })
        let races = (try? ModelContext(container).fetch(descriptor)) ?? []
        let store = PaceProStore()
        for race in races {
            guard let day = Day(iso: race.day) else { continue }
            var plan = store.cachedPlan(race: race.id, distance: race.distance)
            if let client { plan = await store.refresh(race: race.id, distance: race.distance, client: client) ?? plan }
            for notice in RaceNoticeBuilder.notices(id: race.id, name: race.name, day: day, startTime: race.startTime, distance: race.distance, goalSeconds: race.goalSeconds, plan: plan) {
                await scheduler.cancel(id: notice.id)
                guard notice.date > now else { continue }
                await scheduler.schedule(id: notice.id, title: notice.title, text: notice.text, link: C.link, at: notice.date)
            }
        }
    }
}
