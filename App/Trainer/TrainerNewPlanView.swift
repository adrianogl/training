import Insights
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct TrainerNewPlanView: View {
    var isEditing = false
    var suggestedVolumes: (start: Int, peak: Int)? = nil
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var mode = TrainerTargetMode.race
    @State private var raceId: UUID?
    @State private var text = ""
    @State private var hasDeadline = false
    @State private var deadline = Date.now.addingTimeInterval(TrainerConstants.defaultDeadlineSeconds)
    @State private var structure = TrainerEngine.defaultStructure
    @State private var dayPreference = TrainerDayPreference.standard
    @State private var strength: [TrainerStrengthSession] = []
    @State private var strengthLoaded = false
    @State private var startKilometers: Int?
    @State private var peakKilometers: Int?
    @State private var goalPace = TrainerConstants.goalPaceDefault
    @State private var goalKilometers = TrainerConstants.goalDistanceDefault
    @State private var lightWeeks: Set<Day> = []
    @State private var longMode = TrainerLongMode.continuous
    @State private var paceOverrides: [TrainerPaceKind: Double] = [:]
    @State private var preview: [TrainerChange] = []
    @State private var prefilled = false

    private var model: TrainerModel { app.trainer }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $mode) {
                        Text(TrainerText.targetRace).tag(TrainerTargetMode.race)
                        Text(TrainerText.targetText).tag(TrainerTargetMode.text)
                        Text(TrainerText.paceDistanceTarget).tag(TrainerTargetMode.paceDistance)
                    }
                    .pickerStyle(.segmented)
                    targetCard
                    volumeCard
                    daysCards
                    if isEditing { strengthLink }
                    TrainerLongModeCard(mode: longMode, suggestion: model.longSuggestion) { longMode = $0 }
                    if isEditing {
                        TrainerPaceEditCard(
                            history: model.previewPaces(), racePace: target().flatMap { TrainerEngine.racePace($0) },
                            isGoal: mode == .paceDistance, overrides: $paceOverrides
                        )
                        TrainerEditPreviewCard(lines: TrainerText.previewLines(preview))
                    } else {
                        lightWeeksCard
                        pacesCard
                    }
                    Button { create() } label: {
                        HStack(spacing: 8) {
                            if model.isWorking { BrandLoader(size: .mini) }
                            Text(primaryTitle)
                        }
                    }
                        .buttonStyle(TrainerPrimaryButtonStyle())
                        .disabled(!canCreate || model.isWorking)
                        .opacity(canCreate ? 1 : 0.5)
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(isEditing ? TrainerText.editPlanTitle : TrainerText.newPlanTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerText.cancel) { dismiss() } }
                if isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(TrainerText.save) { create() }.disabled(!canCreate || model.isWorking)
                    }
                }
            }
            .navigationDestination(for: TrainerRoute.self) { _ in TrainerStrengthView() }
        }
        .onChange(of: currentEdit) { _, edit in preview = edit.map(model.previewEdit) ?? [] }
        .task {
            await model.load()
            prefill()
            if !isEditing, startKilometers == nil { applySuggestion() }
            if raceId == nil { raceId = model.raceOptions().first?.id }
            if startKilometers == nil { startKilometers = averageKilometers }
            if !strengthLoaded {
                strengthLoaded = true
                strength = model.previewStrength()
            }
        }
    }

    private var primaryTitle: String {
        isEditing ? TrainerText.saveEditButton : mode == .race ? TrainerText.createButton : TrainerText.createTextButton
    }

    private var currentEdit: TrainerEdit? {
        guard isEditing, prefilled, let target = target() else { return nil }
        return model.makeEdit(
            target: target, startMeters: Double(chosenStart) * TrainerConstants.metersPerKilometer,
            peakMeters: Double(chosenPeak) * TrainerConstants.metersPerKilometer, structure: structure, longMode: longMode,
            paceOverrides: paceOverrides, dayPreference: dayPreference
        )
    }

    private var daysCards: some View {
        let peak = Double(chosenPeak) * TrainerConstants.metersPerKilometer
        let paces = isEditing ? model.plan?.paces ?? model.previewPaces() : model.previewPaces()
        let goal = target() ?? TrainerDaysConstants.fallbackTarget
        return TrainerDaysCards(
            preference: Binding(get: { dayPreference }, set: { next in
                dayPreference = next
                structure = TrainerEngine.suggestedStructure(next)
            }),
            structure: $structure, strength: $strength,
            suggested: TrainerEngine.suggestedStructure(dayPreference),
            meters: TrainerEngine.peakWeekMeters(structure: structure, peakMeters: peak, paces: paces, target: goal),
            peakMeters: peak,
            warnings: TrainerEngine.dayWarnings(structure: structure, strength: strength, peakMeters: peak, paces: paces, target: goal),
            showsStrength: !isEditing
        )
    }

    private var strengthLink: some View {
        let sessions = model.plan?.strength ?? []
        return NavigationLink(value: TrainerRoute.strength) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TrainerText.strengthTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(sessions.isEmpty ? TrainerText.strengthCardEmpty : TrainerText.strengthSummary(sessions))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }

    private func prefill() {
        guard isEditing, !prefilled, let current = model.plan, let volumes = model.editVolumes() else { return }
        prefilled = true
        let target = current.target
        switch target.kind {
        case .race:
            mode = .race
            raceId = target.raceId
        case .text:
            mode = .text
            text = target.text ?? target.name
        case .paceDistance:
            mode = .paceDistance
            goalPace = Int((target.goalPace ?? Double(goalPace)).rounded())
            goalKilometers = Int(((target.distanceMeters ?? 0) / TrainerConstants.metersPerKilometer).rounded())
        }
        if let date = target.date, target.kind != .race {
            hasDeadline = true
            deadline = Calendar.current.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) ?? deadline
        }
        startKilometers = volumes.start
        peakKilometers = volumes.peak
        dayPreference = current.dayPreference
        structure = current.structure
        strength = current.strength
        longMode = current.longMode
        paceOverrides = current.paceOverrides
        strengthLoaded = true
        applySuggestion()
    }

    private func applySuggestion() {
        guard let suggestedVolumes else { return }
        startKilometers = suggestedVolumes.start
        peakKilometers = suggestedVolumes.peak
    }

    private var averageKilometers: Int {
        Int((model.previewWeeklyMeters() / TrainerConstants.metersPerKilometer).rounded())
    }

    private var chosenStart: Int { startKilometers ?? averageKilometers }

    private var chosenPeak: Int {
        max(peakKilometers ?? defaultPeak(for: chosenStart), chosenStart)
    }

    private func defaultPeak(for start: Int) -> Int {
        let meters = model.previewPeakMeters(start: Double(start) * TrainerConstants.metersPerKilometer)
        return Int((meters / TrainerConstants.metersPerKilometer).rounded())
    }

    private var datedTarget: Bool {
        mode == .race || hasDeadline
    }

    private var volumeCard: some View {
        let start = chosenStart
        let peak = chosenPeak
        let weeks = model.previewWeeksToPeak(
            start: Double(start) * TrainerConstants.metersPerKilometer, peak: Double(peak) * TrainerConstants.metersPerKilometer
        )
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(TrainerText.startTitle).padding(.vertical, 0)
            Stepper(
                TrainerText.weeklyValue(start),
                value: Binding(get: { start }, set: { startKilometers = $0 }),
                in: TrainerConstants.weeklyKilometersRange
            )
            Text(TrainerText.weeklyAverage(averageKilometers)).font(.footnote).foregroundStyle(BrandColors.dim)
            SectionLabel(TrainerText.peakTitle).padding(.vertical, 0)
            Stepper(
                TrainerText.weeklyValue(peak),
                value: Binding(get: { peak }, set: { peakKilometers = $0 }),
                in: start...TrainerConstants.peakKilometersCeiling
            )
            Text(TrainerText.volumeSummary(start: start, peak: peak, weeks: weeks, dated: datedTarget))
                .font(.footnote).foregroundStyle(BrandColors.dim)
            Text(TrainerText.weeklyHint).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private var races: [TrainerRaceOption] {
        let options = model.raceOptions()
        guard isEditing, let target = model.plan?.target, target.kind == .race, let id = target.raceId, let day = target.date,
              !options.contains(where: { $0.id == id }) else { return options }
        return [TrainerRaceOption(id: id, name: target.name, day: day, distance: target.distanceMeters ?? 0, goalSeconds: target.goalSeconds)] + options
    }

    private var selectedRace: TrainerRaceOption? { races.first { $0.id == raceId } }

    private var canCreate: Bool {
        switch mode {
        case .race: selectedRace != nil
        case .text: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .paceDistance: true
        }
    }

    @ViewBuilder
    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch mode {
            case .race:
                SectionLabel(TrainerText.raceLabel).padding(.vertical, 0)
                if races.isEmpty {
                    Text(TrainerText.noRaces).font(.footnote).foregroundStyle(BrandColors.dim)
                } else {
                    Picker(TrainerText.raceLabel, selection: $raceId) {
                        ForEach(races) { race in
                            Text(raceTitle(race)).tag(Optional(race.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(BrandColors.text)
                }
            case .text:
                SectionLabel(TrainerText.textLabel).padding(.vertical, 0)
                TextField(TrainerText.textPlaceholder, text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                deadlineControls
            case .paceDistance:
                SectionLabel(TrainerText.goalPaceLabel).padding(.vertical, 0)
                Stepper(
                    "\(WorkoutFormat.clock(Double(goalPace)))/km", value: $goalPace,
                    in: TrainerConstants.goalPaceRange, step: TrainerConstants.goalPaceStep
                )
                SectionLabel(TrainerText.distanceLabel).padding(.vertical, 0)
                Stepper("\(goalKilometers) km", value: $goalKilometers, in: TrainerConstants.goalDistanceRange)
                deadlineControls
            }
        }
        .brandCard()
    }

    @ViewBuilder
    private var deadlineControls: some View {
        Toggle(TrainerText.deadlineToggle, isOn: $hasDeadline).font(.footnote)
        if hasDeadline {
            DatePicker(TrainerText.deadlineLabel, selection: $deadline, in: Date.now..., displayedComponents: .date)
                .font(.footnote)
                .environment(\.locale, TrainerConstants.locale)
        }
    }

    private var lightWeeksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(TrainerText.lightWeeksTitle).padding(.vertical, 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(model.previewLightWeekStarts(), id: \.iso) { start in
                    let marked = lightWeeks.contains(start)
                    Button {
                        if marked { lightWeeks.remove(start) } else { lightWeeks.insert(start) }
                    } label: {
                        Text(TrainerText.dayMonth(start))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(marked ? BrandColors.accent : BrandColors.dim)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(marked ? BrandColors.accentGlow : BrandColors.track, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(TrainerText.lightWeeksHint).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private var pacesCard: some View {
        let paces = model.previewPaces()
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(TrainerText.pacesTitle).padding(.vertical, 0)
            HStack(spacing: 8) {
                paceTile(paces.easy, TrainerText.paceEasy, runs: paces.easyRuns)
                paceTile(paces.threshold, TrainerText.paceThreshold, runs: paces.thresholdRuns)
                paceTile(paces.vo2max, TrainerText.paceVo2, runs: paces.vo2Runs)
            }
            ForEach(sourceLines(paces), id: \.self) { line in
                Text(line).font(.caption2).foregroundStyle(BrandColors.dim)
            }
        }
        .brandCard()
    }

    private func sourceLines(_ paces: TrainerPaces) -> [String] {
        [
            TrainerText.paceSource(
                TrainerText.thresholdName, pace: paces.threshold, source: paces.thresholdSource, runs: paces.thresholdWorkRuns,
                work: TrainerText.thresholdRuns
            ),
            TrainerText.paceSource(
                TrainerText.vo2Name, pace: paces.vo2max, source: paces.vo2Source, runs: paces.vo2WorkRuns, work: TrainerText.vo2Runs
            ),
        ].compactMap { $0 }
    }

    private func paceTile(_ seconds: Double, _ label: String, runs: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(WorkoutFormat.clock(seconds)).font(BrandFonts.number(19)).foregroundStyle(BrandColors.text)
            Text("\(label) · \(runs)").font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func raceTitle(_ race: TrainerRaceOption) -> String {
        "\(race.name) · \(TrainerText.dayMonth(race.day))"
    }

    private func create() {
        guard let target = target() else { return }
        if isEditing {
            Task {
                if let edit = currentEdit { await model.saveEdit(edit) }
                dismiss()
            }
            return
        }
        Task {
            await model.createPlan(
                target: target, structure: structure, strength: strength,
                startMeters: Double(chosenStart) * TrainerConstants.metersPerKilometer,
                peakMeters: Double(chosenPeak) * TrainerConstants.metersPerKilometer,
                lightWeeks: lightWeeks.sorted(), longMode: longMode, dayPreference: dayPreference
            )
            dismiss()
        }
    }

    private func target() -> TrainerTarget? {
        switch mode {
        case .race:
            guard let race = selectedRace else { return nil }
            return TrainerTarget(kind: .race, name: race.name, raceId: race.id, date: race.day, distanceMeters: race.distance, goalSeconds: race.goalSeconds)
        case .text:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return TrainerTarget(kind: .text, name: trimmed, date: hasDeadline ? Day.today(now: deadline) : nil, text: trimmed)
        case .paceDistance:
            return TrainerTarget(
                kind: .paceDistance, name: TrainerText.paceGoalName(pace: goalPace, kilometers: goalKilometers),
                date: hasDeadline ? Day.today(now: deadline) : nil,
                distanceMeters: Double(goalKilometers) * TrainerConstants.metersPerKilometer, goalPace: Double(goalPace)
            )
        }
    }
}
