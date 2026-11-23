import ActivityKit
import Foundation
import GarminAPI
import Insights
import MFIT
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
    @ObservationIgnored var garminClient: (@MainActor () -> GarminAccountClient?)?
    @ObservationIgnored private var uploading = false

    var live: StrengthLiveSnapshot? {
        guard let snapshot, snapshot.finish == nil, Date.now.timeIntervalSince(snapshot.startedAt) < StrengthLiveConstants.staleAfter,
              LiveStrengthQueue.next(snapshot.session) != nil else { return nil }
        return snapshot
    }

    var finished: StrengthLiveSnapshot? {
        guard let snapshot, let finish = snapshot.finish, finish.saved,
              Day.today(now: finish.at) == Day.today() else { return nil }
        return snapshot
    }

    func summary(_ snapshot: StrengthLiveSnapshot) -> LiveStrengthSummary {
        LiveStrengthReport.summarize(
            snapshot.session, durationSeconds: snapshot.finish?.durationSeconds ?? 0, averageHeartRate: snapshot.finish?.averageHeartRate
        )
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

    func finished(at finishedAt: Date, saved: Bool, durationSeconds: Double, averageHeartRate: Int?) {
        guard var current = snapshot, current.finish == nil else { return }
        current.finish = StrengthLiveFinish(
            at: finishedAt, saved: saved, durationSeconds: durationSeconds, averageHeartRate: averageHeartRate,
            activityId: nil, upload: saved ? .pending : .notFound
        )
        snapshot = current
        persist()
        if let id = activity?.id {
            Task { await Self.end(id, content: nil, dismissal: .immediate) }
            activity = nil
        }
        uploadPending()
        Task {
            for delay in StrengthLiveConstants.uploadRetries {
                try? await Task.sleep(for: delay)
                uploadPending()
            }
        }
    }

    func appBecameActive() {
        showActivity()
        uploadPending()
    }

    func uploadPending() {
        guard !uploading, let snapshot, let finish = snapshot.finish, finish.saved,
              finish.upload == .pending || finish.upload == .notFound || finish.upload == .failed,
              Date.now.timeIntervalSince(finish.at) < StrengthLiveConstants.uploadWindow,
              let client = garminClient?() else { return }
        uploading = true
        Task {
            let result = await Self.upload(snapshot, client: client)
            uploading = false
            guard var current = self.snapshot, current.startedAt == snapshot.startedAt else { return }
            current.finish?.upload = result.state
            current.finish?.activityId = result.activityId
            self.snapshot = current
            persist()
            if result.state == .sent, let activityId = result.activityId {
                _ = StrengthProgramStore().addWatchLoads(Self.loadRecords(current.session), activity: activityId)
            }
        }
    }

    static func loadRecords(_ session: LiveStrengthSession) -> [MFITLoadRecord] {
        let plan = session.plan
        return LiveStrengthReport.realLoads(session).map { load in
            MFITLoadRecord(
                exercise: load.name,
                key: plan.source == .mfit ? load.loadKey : MFITParser.exerciseKey(load.name),
                day: plan.day,
                loads: load.loads,
                workoutId: plan.sourceId ?? 0,
                fromWatch: true
            )
        }
    }

    private static func upload(_ snapshot: StrengthLiveSnapshot, client: GarminAccountClient) async -> (state: StrengthLiveUploadState, activityId: Int64?) {
        let sets = LiveStrengthUpload.sets(snapshot.session)
        guard !sets.isEmpty else { return (.sent, nil) }
        guard let data = try? await client.get(GarminEndpoints.activitiesPath + StrengthLiveConstants.activitiesQuery),
              let activities = try? JSONDecoder().decode([ActivityDTO].self, from: data) else { return (.failed, nil) }
        guard let activity = LiveStrengthUpload.match(activities, startedAt: snapshot.startedAt) else { return (.notFound, nil) }
        guard let existing = try? await ExerciseSets.fetch(client: client, activityId: activity.activityId) else { return (.failed, activity.activityId) }
        guard existing.isEmpty else { return (.alreadyHadSets, activity.activityId) }
        do {
            try await ExerciseSetsUpload.upload(client: client, activityId: activity.activityId, sets: sets)
            return (.sent, activity.activityId)
        } catch {
            return (.failed, activity.activityId)
        }
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
