import Insights
import SwiftUI
import TrainingCore

struct StrengthPlanFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: StrengthPlanDraft
    @State private var editing: TrainerStrengthDraft?
    @State private var confirmingEnd = false
    let today: Day
    let onSave: (StrengthPlan) -> Void
    let onEnd: () -> Void

    init(draft: StrengthPlanDraft, today: Day, onSave: @escaping (StrengthPlan) -> Void, onEnd: @escaping () -> Void = {}) {
        _draft = State(initialValue: draft)
        self.today = today
        self.onSave = onSave
        self.onEnd = onEnd
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                StrengthPlanFormContent(
                    draft: $draft, confirmingEnd: $confirmingEnd, today: today,
                    onEditSession: { editing = TrainerStrengthDraft(session: $0, isNew: false) },
                    onAddDay: addDay,
                    onSubmit: submit,
                    onEnd: {
                        onEnd()
                        dismiss()
                    }
                )
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(draft.isNew ? StrengthPlanText.newTitle : StrengthPlanText.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(StrengthPlanText.cancel) { dismiss() } }
            }
            .sheet(item: $editing) { session in
                TrainerStrengthEditView(draft: session, blockedDays: blockedDays(for: session.session)) { apply($0) }
            }
        }
    }

    private func blockedDays(for session: TrainerStrengthSession) -> Set<Int> {
        Set(draft.sessions.filter { $0.id != session.id }.map(\.weekday))
    }

    private func addDay() {
        guard let weekday = StrengthPlanDraftLogic.nextFreeWeekday(draft.sessions) else { return }
        editing = TrainerStrengthDraft(session: StrengthPlanDraftLogic.newSession(objective: draft.objective, weekday: weekday), isNew: true)
    }

    private func apply(_ result: TrainerStrengthResult) {
        switch result {
        case .save(let session):
            if let index = draft.sessions.firstIndex(where: { $0.id == session.id }) {
                draft.sessions[index] = session
            } else {
                draft.sessions.append(session)
            }
        case .remove(let id):
            draft.sessions.removeAll { $0.id == id }
        }
        draft.sessions.sort { $0.weekday < $1.weekday }
        if !draft.startEdited {
            draft.start = StrengthPlanDraftLogic.defaultStart(draft.sessions, today: today)
        }
    }

    private func submit() {
        guard let plan = StrengthPlanDraftLogic.plan(draft) else { return }
        onSave(plan)
        dismiss()
    }
}

struct StrengthPlanFormContent: View {
    @Binding var draft: StrengthPlanDraft
    @Binding var confirmingEnd: Bool
    let today: Day
    let onEditSession: (TrainerStrengthSession) -> Void
    let onAddDay: () -> Void
    let onSubmit: () -> Void
    let onEnd: () -> Void
    @State private var pickingStart = false
    @State private var pickingUntil = false

    private typealias C = StrengthPlanUIConstants

    var body: some View {
        VStack(alignment: .leading, spacing: C.spacing) {
            section(StrengthPlanText.objectiveTitle, first: true)
            objectiveCard
            section(StrengthPlanText.daysTitle)
            daysCard
            section(StrengthPlanText.validityTitle)
            validityCard
            section(StrengthPlanText.builderTitle)
            builderCard
            Button(draft.isNew ? StrengthPlanText.create : StrengthPlanText.save, action: onSubmit)
                .buttonStyle(.ds(.primary))
                .disabled(StrengthPlanDraftLogic.plan(draft) == nil)
                .padding(.top, DSSpacing.s1)
            if !draft.isNew { endSection }
        }
    }

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: C.spacing) {
            StrengthPlanOptionList(
                options: C.objectiveOrder, selection: $draft.objective, name: StrengthPlanText.objectiveName, detail: StrengthPlanText.objectiveHint
            )
        }
        .brandCard()
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if draft.sessions.isEmpty {
                Text(StrengthPlanText.noDays).font(.footnote).foregroundStyle(BrandColors.dim).padding(.bottom, DSSpacing.s2)
            }
            ForEach(Array(draft.sessions.enumerated()), id: \.element.id) { index, session in
                if index > 0 { divider }
                Button { onEditSession(session) } label: { row(session) }
                    .buttonStyle(.plain)
            }
            if StrengthPlanDraftLogic.nextFreeWeekday(draft.sessions) != nil {
                divider
                Button(action: onAddDay) {
                    Text(StrengthPlanText.addDay).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        .frame(maxWidth: .infinity, minHeight: C.rowMinHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .brandCard()
    }

    private var divider: some View {
        Rectangle().fill(BrandColors.line).frame(height: 1)
    }

    private func row(_ session: TrainerStrengthSession) -> some View {
        HStack(spacing: C.spacing) {
            Text(StrengthPlanText.dayShort(session.weekday))
                .font(.subheadline.weight(.bold)).foregroundStyle(BrandColors.strength)
                .frame(width: C.dayColumnWidth, alignment: .leading)
            Text(StrengthPlanText.sessionLine(session)).font(.subheadline).foregroundStyle(BrandColors.text)
            Spacer(minLength: DSSpacing.s2)
            Text(StrengthPlanText.minutes(session.minutes)).font(.footnote).foregroundStyle(BrandColors.dim)
        }
        .frame(minHeight: C.rowMinHeight)
        .contentShape(Rectangle())
    }

    private var validityCard: some View {
        VStack(alignment: .leading, spacing: C.spacing) {
            StrengthPlanSegmented(
                options: C.validityOrder, selection: $draft.mode, name: StrengthPlanText.validityName,
                isEnabled: { $0 != .untilRace || draft.race != nil }
            )
            switch draft.mode {
            case .weeks:
                StrengthPlanField(label: StrengthPlanText.durationLabel) { weeksStepper }
            case .untilDate:
                dateField(StrengthPlanText.untilLabel, day: draft.untilDate, expanded: $pickingUntil)
                if pickingUntil {
                    picker(selection: $draft.untilDate, from: draft.start)
                }
            case .untilRace:
                StrengthPlanField(label: StrengthPlanText.raceLabel) {
                    Text(draft.race.map(StrengthPlanText.raceValue) ?? "").font(.subheadline).foregroundStyle(BrandColors.dim)
                }
            }
            dateField(StrengthPlanText.startLabel, day: draft.start, expanded: $pickingStart)
            if pickingStart {
                picker(selection: startBinding, from: min(today, draft.start))
            }
            if let plan = StrengthPlanDraftLogic.plan(draft) {
                Text(StrengthPlanText.summary(end: plan.end, planned: plan.plannedCount())).font(.footnote).foregroundStyle(BrandColors.dim)
            }
        }
        .brandCard()
    }

    private var weeksStepper: some View {
        HStack(spacing: 0) {
            stepButton(C.stepperSymbolMinus, enabled: draft.weeks > C.weeksRange.lowerBound) { draft.weeks -= 1 }
            Text(StrengthPlanText.weeks(draft.weeks)).font(.subheadline).foregroundStyle(BrandColors.dim).monospacedDigit()
            stepButton(C.stepperSymbolPlus, enabled: draft.weeks < C.weeksRange.upperBound) { draft.weeks += 1 }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(BrandColors.text)
                .frame(width: C.segmentHeight, height: C.segmentHeight)
                .background(BrandColors.track, in: Circle())
                .frame(width: C.hitSize, height: C.hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : DSButtonConstants.disabledOpacity)
    }

    private func dateField(_ label: String, day: Day, expanded: Binding<Bool>) -> some View {
        Button { expanded.wrappedValue.toggle() } label: {
            StrengthPlanField(label: label) {
                Text(StrengthPlanText.weekdayDate(day)).font(.subheadline).foregroundStyle(expanded.wrappedValue ? BrandColors.accent : BrandColors.dim)
            }
        }
        .buttonStyle(.plain)
    }

    private var startBinding: Binding<Day> {
        Binding {
            draft.start
        } set: { day in
            draft.start = day
            draft.startEdited = true
            if draft.untilDate < day { draft.untilDate = day }
        }
    }

    private func picker(selection: Binding<Day>, from first: Day) -> some View {
        DatePicker(
            "",
            selection: Binding { StrengthPlanDraftLogic.date(selection.wrappedValue) } set: { selection.wrappedValue = Day.today(now: $0) },
            in: StrengthPlanDraftLogic.date(first)...,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .tint(BrandColors.accent)
        .labelsHidden()
    }

    private var builderCard: some View {
        VStack(alignment: .leading, spacing: C.spacing) {
            StrengthPlanSegmented(options: C.builderOrder, selection: $draft.builder, name: StrengthPlanText.builderName)
            Text(StrengthPlanText.builderHint).font(.footnote).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    @ViewBuilder
    private var endSection: some View {
        if confirmingEnd {
            DSNotice(tone: .error, title: StrengthPlanText.endConfirmTitle, text: StrengthPlanText.endConfirmBody) {
                HStack(spacing: DSSpacing.s4) {
                    Button(StrengthPlanText.endConfirm, role: .destructive, action: onEnd).buttonStyle(.ds(.destructive))
                    Button(StrengthPlanText.endKeep) { confirmingEnd = false }.buttonStyle(.ds(.text))
                }
            }
        } else {
            Button(StrengthPlanText.endPlan, role: .destructive) { confirmingEnd = true }
                .buttonStyle(.ds(.destructive))
                .frame(maxWidth: .infinity)
        }
    }

    private func section(_ title: String, first: Bool = false) -> some View {
        DSSectionTitle(title)
            .padding(.top, first ? DSSpacing.s1 : DSSpacing.sectionTop - C.spacing)
            .padding(.bottom, DSSpacing.sectionBottom - C.spacing)
    }
}
