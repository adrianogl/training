import ActivityKit
import Foundation
import Insights
import Observation
import TrainingCore
import UIKit

@MainActor
@Observable
final class StrengthLiveModel {
    static let shared = StrengthLiveModel()

    @ObservationIgnored private let store = StrengthLiveStore()
    private(set) var snapshot: StrengthLiveSnapshot?
    @ObservationIgnored private var activity: Activity<StrengthLiveAttributes>?

    var live: StrengthLiveSnapshot? {
        guard let snapshot, Date.now.timeIntervalSince(snapshot.startedAt) < StrengthLiveConstants.staleAfter,
              LiveStrengthQueue.next(snapshot.session) != nil else { return nil }
        return snapshot
    }

    private init() {
        snapshot = store.load()
        activity = Activity<StrengthLiveAttributes>.activities.first
    }

    func started(at startedAt: Date, title: String?) {
        guard let plan = plan(for: startedAt, title: title) else { return }
        snapshot = StrengthLiveSnapshot(startedAt: startedAt, session: LiveStrengthSession(plan: plan))
        persist()
        if let id = activity?.id {
            Task { await Self.end(id, content: nil, dismissal: .immediate) }
            activity = nil
        }
        showActivity()
    }

    func receive(_ events: [LiveStrengthEvent]) {
        if snapshot == nil, let plan = plan(for: .now, title: nil) {
            snapshot = StrengthLiveSnapshot(startedAt: .now, session: LiveStrengthSession(plan: plan))
        }
        guard var current = snapshot else { return }
        current.session = LiveStrengthQueue.receive(events, into: current.session)
        snapshot = current
        persist()
        showActivity()
    }

    func receive(_ status: LiveStrengthWatchStatus) {
        guard var current = snapshot else { return }
        current.status = status
        snapshot = current
        persist()
        showActivity()
    }

    func appBecameActive() {
        showActivity()
    }

    private func showActivity() {
        guard let snapshot, Date.now.timeIntervalSince(snapshot.startedAt) < StrengthLiveConstants.staleAfter else { return }
        let card = LiveStrengthLive.card(session: snapshot.session, status: snapshot.status)
        let state = Self.state(card)
        let content = ActivityContent(state: state, staleDate: nil)
        if let id = activity?.id {
            if state.moment == .finished {
                Task { await Self.end(id, content: content, dismissal: .default) }
                activity = nil
            } else {
                Task { await Self.update(id, content: content) }
            }
            return
        }
        guard state.moment != .finished, UIApplication.shared.applicationState == .active,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(attributes: StrengthLiveAttributes(title: card.title), content: content)
    }

    private static func update(_ id: String, content: ActivityContent<StrengthLiveAttributes.ContentState>) async {
        for activity in Activity<StrengthLiveAttributes>.activities where activity.id == id {
            await activity.update(content)
        }
    }

    private static func end(_ id: String, content: ActivityContent<StrengthLiveAttributes.ContentState>?, dismissal: ActivityUIDismissalPolicy) async {
        for activity in Activity<StrengthLiveAttributes>.activities where activity.id == id {
            await activity.end(content, dismissalPolicy: dismissal)
        }
    }

    private func plan(for startedAt: Date, title: String?) -> LiveStrengthPlan? {
        let day = Day.today(now: startedAt).iso
        let plans = store.sentPlans().filter { $0.day == day }
        return plans.first { $0.title == title } ?? plans.first
    }

    private func persist() {
        guard let snapshot else { return }
        store.save(snapshot)
    }

    static func state(_ card: LiveStrengthCard) -> StrengthLiveAttributes.ContentState {
        StrengthLiveAttributes.ContentState(
            moment: StrengthLiveMoment(rawValue: card.moment.rawValue) ?? .doing,
            setsDone: card.setsDone,
            setsTotal: card.setsTotal,
            heartRate: card.heartRate,
            exerciseName: card.exerciseName,
            shortName: card.shortName,
            setNumber: card.setNumber,
            setCount: card.setCount,
            exerciseSetsDone: card.exerciseSetsDone,
            target: card.target,
            last: card.last,
            lastDone: card.lastDone,
            restEndsAt: card.restEndsAt,
            restSeconds: card.restSeconds
        )
    }
}
