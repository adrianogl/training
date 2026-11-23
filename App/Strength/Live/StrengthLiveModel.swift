import ActivityKit
import Foundation
import GarminAPI
import Insights
import MFIT
import Observation
import SwiftUI
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
    private(set) var pendingCommand: StrengthLivePendingCommand?
    var watchConnected = false
    private(set) var notice: String?
    private(set) var highlighted: String?

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

    func started(at startedAt: Date, version: String?) {
        if let id = activity?.id {
            Task { await Self.end(id, content: nil, dismissal: .immediate) }
            activity = nil
        }
        guard let version, let plan = store.sentPlan(version: version) else {
            snapshot = nil
            store.clear()
            return
        }
        snapshot = StrengthLiveSnapshot(startedAt: startedAt, session: LiveStrengthSession(plan: plan))
        persist()
        showActivity()
    }

    func receive(_ events: [LiveStrengthEvent]) {
        guard var current = snapshot, current.finish == nil,
              Date.now.timeIntervalSince(current.startedAt) < StrengthLiveConstants.staleAfter else { return }
        current.session = LiveStrengthQueue.receive(events, into: current.session)
        withAnimation(.snappy) { snapshot = current }
        persist()
        showActivity()
        confirmCommand(events, plan: current.session.plan)
    }

    func request(_ command: StrengthLiveCommand, exerciseId: String) {
        guard pendingCommand == nil else { return }
        let pending = StrengthLivePendingCommand(kind: command, exerciseId: exerciseId, sentAt: .now)
        pendingCommand = pending
        WatchLink.shared.sendCommand(command.rawValue, exerciseId: exerciseId)
        Task {
            try? await Task.sleep(for: StrengthLiveConstants.commandTimeout)
            guard self.pendingCommand == pending else { return }
            self.pendingCommand = nil
            self.show(StrengthLiveText.commandTimeout)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func show(_ text: String) {
        notice = text
        Task {
            try? await Task.sleep(for: StrengthLiveConstants.noticeSeconds)
            if self.notice == text { self.notice = nil }
        }
    }

    private func confirmCommand(_ events: [LiveStrengthEvent], plan: LiveStrengthPlan) {
        guard let pending = pendingCommand else { return }
        let matched = events.contains { event in
            switch (event.action, pending.kind) {
            case (.skip(let id), .skip), (.doNow(let id), .doNow): id == pending.exerciseId
            default: false
            }
        }
        guard matched, let exercise = plan.exercise(pending.exerciseId) else { return }
        pendingCommand = nil
        highlighted = exercise.id
        show(StrengthLiveText.commandNotice(pending.kind, name: exercise.name))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            try? await Task.sleep(for: StrengthLiveConstants.highlightSeconds)
            if self.highlighted == exercise.id { self.highlighted = nil }
        }
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
        if saved { store.saveNextLoads(LiveStrengthReport.nextLoads(current.session)) }
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
        guard let snapshot, snapshot.finish == nil, Date.now.timeIntervalSince(snapshot.startedAt) < StrengthLiveConstants.staleAfter else { return }
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
