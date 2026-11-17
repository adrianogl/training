import Insights
import SwiftUI

struct TrainerStrengthView: View {
    @Environment(AppModel.self) private var app
    @State private var editing: TrainerStrengthDraft?
    @State private var showsPain = false

    private var model: TrainerModel { app.trainer }
    private var sessions: [TrainerStrengthSession] { (model.plan?.strength ?? []).sorted { $0.weekday < $1.weekday } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrainerStrengthConstants.rowSpacing) {
                daysCard
                if model.suggestedStrength() != sessions, sessions.contains(where: { $0.source == .trainer }) {
                    suggestionCard
                }
                Button { showsPain = true } label: {
                    Label(TrainerStrengthText.painButton, systemImage: TrainerStrengthConstants.painSymbol)
                }
                .buttonStyle(TrainerSecondaryButtonStyle())
                if sessions.contains(where: { $0.source == .mfit }) {
                    Text(TrainerStrengthText.mfitReadOnly).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, 2)
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
            TrainerStrengthEditView(draft: draft, blockedDays: Set(sessions.filter { $0.source == .mfit }.map(\.weekday))) { save($0) }
        }
        .sheet(isPresented: $showsPain) { TrainerPainSheet() }
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(TrainerStrengthText.daysTitle).padding(.vertical, 0)
            HStack(spacing: 6) {
                ForEach(1...TrainerConstants.weekdayCount, id: \.self) { weekday in
                    dayChip(weekday)
                }
            }
            SectionLabel(TrainerStrengthText.perDayTitle).padding(.top, 4).padding(.bottom, 0)
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
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
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
            .buttonStyle(TrainerSecondaryButtonStyle())
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
        var all = model.plan?.strength ?? []
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
        let color = source == .trainer ? BrandColors.strength : BrandColors.dim
        Text(TrainerStrengthText.sourceName(source))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
                    .buttonStyle(TrainerPrimaryButtonStyle())
                    if !isNew {
                        Button(TrainerStrengthText.remove, role: .destructive) {
                            onResult(.remove(session.id))
                            dismiss()
                        }
                        .buttonStyle(TrainerSecondaryButtonStyle())
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
