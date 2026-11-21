import GarminAPI
import Insights
import SwiftUI
import TrainingCore
import UIKit

struct TrainerStrengthView: View {
    @Environment(AppModel.self) private var app
    @State private var editing: TrainerStrengthDraft?
    @State private var showsPain = false
    @State private var showsSend = false
    @State private var showsClaudeRequest = false
    @State private var claudeImport: ClaudeImportState?
    @State private var inbox: ClaudeInbox?
    @State private var inboxPreview: ClaudeImportState?

    private var model: TrainerModel { app.trainer }
    private var sessions: [TrainerStrengthSession] { model.strengthSessions.sorted { $0.weekday < $1.weekday } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrainerStrengthConstants.rowSpacing) {
                section(TrainerStrengthText.daysTitle, first: true)
                daysCard
                if model.suggestedStrength() != sessions, sessions.contains(where: { $0.source == .trainer }) {
                    suggestionCard
                }
                if let inbox, let preview = inboxPreview {
                    inboxCard(inbox, preview: preview)
                }
                if sessions.contains(where: { $0.source == .trainer }) {
                    section(ClaudeText.source)
                    claudeCard
                }
                Button { showsPain = true } label: {
                    Label(TrainerStrengthText.painButton, systemImage: TrainerStrengthConstants.painSymbol)
                }
                .buttonStyle(.ds(.secondary))
                if sessions.contains(where: { $0.source == .mfit }) {
                    Text(TrainerStrengthText.mfitReadOnly).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, 2)
                }
                if model.plan == nil {
                    section(TrainerStrengthText.upcomingTitle)
                    upcomingCard
                    Button { showsSend = true } label: {
                        Label(app.watchKind == .appleWatch ? TrainerSendText.appleOpenButton : TrainerSendText.openButton, systemImage: "applewatch")
                    }
                    .buttonStyle(.ds(.primary))
                    Text(TrainerStrengthText.noPlanNote).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(TrainerText.strengthTitle)
        .sheet(item: $editing) { draft in
            TrainerStrengthEditView(draft: draft) { save($0) }
        }
        .sheet(isPresented: $showsPain) { TrainerPainSheet() }
        .sheet(isPresented: $showsSend) { TrainerSendSheet() }
        .sheet(isPresented: $showsClaudeRequest) { ClaudeRequestSheet(race: raceTarget) }
        .sheet(item: $claudeImport) { state in
            ClaudeImportSheet(summary: state.summary, results: state.results, failure: state.failure, planNotice: model.planNotice(for: state)) {
                model.applyClaudeImport(state)
                unscheduleReplacedMFIT(state.results)
                if let inbox, state.id == inboxPreview?.id {
                    ClaudeMailbox().markSeen(inbox)
                    self.inbox = nil
                }
            }
        }
        .task(id: app.remoteSync.lastSync) { refreshClaude() }
        .onChange(of: sessions) { refreshClaude() }
    }

    private var raceTarget: ClaudeRaceTarget? {
        if let plan = model.plan, plan.target.kind == .race, let date = plan.target.date, date > model.currentDay {
            return ClaudeRaceTarget(name: plan.target.name, day: date)
        }
        guard let race = try? targetRace(in: app.container.mainContext, today: model.currentDay), let day = Day(iso: race.day) else { return nil }
        return ClaudeRaceTarget(name: race.name, day: day)
    }

    private func unscheduleReplacedMFIT(_ results: [ClaudeDayResult]) {
        let days = results.filter { $0.isValid && $0.replacesMFIT }.compactMap(\.day)
        guard !days.isEmpty, let client = app.garminAccount.client else { return }
        let created = Set(TrainerSendStore().records().values.map(\.workoutId))
        Task {
            for day in days {
                _ = try? await GarminPlannedUpload.unscheduleStrength(client: client, on: day, keeping: created)
            }
        }
    }

    private func refreshClaude() {
        if model.publishClaudeContext(race: raceTarget) {
            app.remoteSync.scheduleSync()
        }
        inbox = ClaudeMailbox().unseen()
        inboxPreview = inbox.map { model.claudeInboxResults($0, race: raceTarget) }
    }

    private func inboxCard(_ inbox: ClaudeInbox, preview: ClaudeImportState) -> some View {
        let valid = preview.results.filter(\.isValid).count
        let shape = RoundedRectangle(cornerRadius: TrainerStrengthConstants.bannerCorner, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(ClaudeText.inboxTitle).font(.subheadline.weight(.bold)).foregroundStyle(ClaudeConstants.color)
                Spacer()
                Text(inbox.savedAt.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(BrandColors.dim)
            }
            if let summary = preview.summary {
                Text("\"\(summary)\"").font(.footnote).foregroundStyle(BrandColors.text)
            }
            Text(ClaudeText.inboxCount(total: preview.results.count, valid: valid))
                .font(.caption).foregroundStyle(BrandColors.dim)
            Button(ClaudeText.review) { claudeImport = preview }
                .buttonStyle(.ds(.primary))
            Button(ClaudeText.discard) {
                ClaudeMailbox().markSeen(inbox)
                self.inbox = nil
            }
            .buttonStyle(.ds(.secondary))
        }
        .padding(12)
        .background(ClaudeConstants.color.opacity(TrainerStrengthConstants.bannerTint), in: shape)
        .overlay(shape.strokeBorder(ClaudeConstants.color, lineWidth: TrainerStrengthConstants.bannerBorder))
    }

    private var claudeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(ClaudeText.askButton) { showsClaudeRequest = true }
                .buttonStyle(.ds(.secondary))
            Button(ClaudeText.pasteButton) { pasteFromClaude() }
                .buttonStyle(.ds(.secondary))
        }
        .brandCard()
    }

    private func pasteFromClaude() {
        claudeImport = model.claudeImportState(parsing: UIPasteboard.general.string ?? "", race: raceTarget)
    }

    private var upcomingCard: some View {
        let days = (0..<TrainerSendConstants.windowDays).map { model.currentDay.adding(days: $0) }
        let entries = days.flatMap { day in model.trainerSessions(on: day).map { (day: day, session: $0) } }
        return VStack(alignment: .leading, spacing: 4) {
            if entries.isEmpty {
                Text(TrainerStrengthText.upcomingEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            ForEach(entries, id: \.session.id) { entry in
                NavigationLink(value: TrainerRoute.strengthDay(entry.day.iso, entry.session.id)) {
                    HStack(spacing: 10) {
                        Text(TrainerText.weekdayName(entry.day.weekStart.days(until: entry.day)))
                            .font(.caption.weight(.bold)).foregroundStyle(BrandColors.text)
                            .frame(width: TrainerConstants.dayDateWidth, alignment: .leading)
                        if let workout = model.strengthWorkout(sessionId: entry.session.id, day: entry.day) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(TrainerStrengthText.focusName(workout.group)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                                Text(TrainerStrengthText.meta(workout)).font(.caption).foregroundStyle(BrandColors.dim)
                            }
                        }
                        Spacer(minLength: 6)
                        if model.isClaudeDay(entry.day) { ClaudeSourceChip() }
                        CardLinkChevron()
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.cardLink)
            }
        }
        .brandCard()
    }

    private func section(_ title: String, first: Bool = false) -> some View {
        DSSectionTitle(title)
            .padding(.top, first ? 4 : DSSpacing.sectionTop - TrainerStrengthConstants.rowSpacing)
            .padding(.bottom, DSSpacing.sectionBottom - TrainerStrengthConstants.rowSpacing)
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(1...TrainerConstants.weekdayCount, id: \.self) { weekday in
                    dayChip(weekday)
                }
            }
            .padding(.bottom, 4)
            if sessions.isEmpty {
                Text(TrainerText.strengthEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            ForEach(sessions) { session in
                if session.source == .trainer {
                    Button { editing = TrainerStrengthDraft(session: session, isNew: false) } label: { row(session) }
                        .buttonStyle(.plain)
                } else {
                    row(session)
                }
            }
        }
        .brandCard()
    }

    private func dayChip(_ weekday: Int) -> some View {
        let session = sessions.first { $0.weekday == weekday }
        let fill = session == nil ? Color.clear : BrandColors.strength
        return Button {
            if let session {
                if session.source == .trainer { save(.remove(session.id)) }
            } else {
                editing = TrainerStrengthDraft(session: newSession(weekday), isNew: true)
            }
        } label: {
            Text(TrainerText.weekdayName(weekday - 1))
                .font(.caption.weight(.bold))
                .foregroundStyle(session == nil ? BrandColors.dim : BrandColors.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(fill, in: RoundedRectangle(cornerRadius: TrainerStrengthConstants.dayChipCorner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TrainerStrengthConstants.dayChipCorner, style: .continuous).strokeBorder(BrandColors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(session?.source == .mfit)
    }

    private func row(_ session: TrainerStrengthSession) -> some View {
        HStack(spacing: 10) {
            Text(TrainerText.weekdayName(session.weekday - 1))
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColors.text)
                .frame(width: TrainerConstants.dayDateWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.source == .mfit ? session.name : TrainerStrengthText.focusName(session.group))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(TrainerStrengthText.caption(session)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 6)
            TrainerStrengthSourceChip(source: session.source)
            if session.source == .trainer {
                CardLinkChevron()
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(TrainerStrengthText.suggestionTitle, systemImage: TrainerStrengthConstants.suggestionSymbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(BrandColors.strength)
            ForEach(model.suggestedStrength().filter { $0.source == .trainer }) { session in
                Text("\(TrainerText.weekdayName(session.weekday - 1)) · \(TrainerStrengthText.focusName(session.group)) · \(TrainerStrengthText.caption(session))")
                    .font(.footnote)
                    .foregroundStyle(BrandColors.text)
            }
            Button(TrainerStrengthText.useSuggestion) {
                Task { await model.saveStrength(model.suggestedStrength()) }
            }
            .buttonStyle(.ds(.secondary))
        }
        .padding(12)
        .background(BrandColors.strengthGlow, in: RoundedRectangle(cornerRadius: TrainerStrengthConstants.bannerCorner, style: .continuous))
    }

    private func newSession(_ weekday: Int) -> TrainerStrengthSession {
        TrainerStrengthSession(
            weekday: weekday, group: .core, legLoad: .light, name: TrainerStrengthText.focusName(.core),
            source: .trainer, intensity: .light, minutes: 25, place: .home
        )
    }

    private func save(_ result: TrainerStrengthResult) {
        var all = model.strengthSessions
        switch result {
        case .save(let session):
            if let index = all.firstIndex(where: { $0.id == session.id }) {
                all[index] = session
            } else {
                all.append(session)
            }
        case .remove(let id):
            all.removeAll { $0.id == id }
        }
        Task { await model.saveStrength(all) }
    }
}

struct TrainerStrengthSourceChip: View {
    let source: TrainerStrengthSource

    var body: some View {
        DSChip(text: TrainerStrengthText.chipName(source), tone: source == .trainer ? .strength : .neutral)
    }
}

struct TrainerStrengthEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: TrainerStrengthSession
    let isNew: Bool
    let blockedDays: Set<Int>
    let onResult: (TrainerStrengthResult) -> Void

    init(draft: TrainerStrengthDraft, blockedDays: Set<Int> = [], onResult: @escaping (TrainerStrengthResult) -> Void) {
        _session = State(initialValue: draft.session)
        isNew = draft.isNew
        self.blockedDays = blockedDays
        self.onResult = onResult
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker(TrainerText.strengthDayLabel, selection: $session.weekday) {
                            ForEach((1...TrainerConstants.weekdayCount).filter { !blockedDays.contains($0) }, id: \.self) { weekday in
                                Text(TrainerConstants.weekdayFull[weekday - 1].capitalized).tag(weekday)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(BrandColors.text)
                        segmented(TrainerStrengthText.focusLabel, selection: $session.group, options: TrainerStrengthConstants.focusOrder, name: TrainerStrengthText.focusName)
                        segmented(TrainerStrengthText.intensityLabel, selection: $session.intensity, options: TrainerStrengthConstants.intensityOrder, name: TrainerStrengthText.intensityName)
                        segmented(TrainerStrengthText.durationLabel, selection: $session.minutes, options: TrainerStrengthConstants.minuteOptions) { String(format: TrainerStrengthText.minutesFormat, $0) }
                        segmented(TrainerStrengthText.placeLabel, selection: $session.place, options: TrainerStrengthConstants.placeOrder, name: TrainerStrengthText.placeName)
                    }
                    .brandCard()
                    Button(TrainerStrengthText.save) {
                        session.legLoad = StrengthSessions.legLoad(group: session.group, intensity: session.intensity)
                        session.name = TrainerStrengthText.focusName(session.group)
                        session.source = .trainer
                        onResult(.save(session))
                        dismiss()
                    }
                    .buttonStyle(.ds(.primary))
                    if !isNew {
                        Button(TrainerStrengthText.remove, role: .destructive) {
                            onResult(.remove(session.id))
                            dismiss()
                        }
                        .buttonStyle(.ds(.secondary))
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(isNew ? TrainerText.strengthNewTitle : TrainerText.strengthEditTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerText.cancel) { dismiss() } }
            }
        }
    }

    private func segmented<Value: Hashable>(_ title: String, selection: Binding<Value>, options: [Value], name: @escaping (Value) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(name($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
