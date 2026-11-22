import Insights
import SwiftUI

struct TrainerDaysCards: View {
    @Binding var preference: TrainerDayPreference
    @Binding var structure: [Int: TrainerDayKind]
    @Binding var strength: [TrainerStrengthSession]
    @Binding var outAndBack: Bool
    let suggested: [Int: TrainerDayKind]
    let meters: [Int: Double]
    let peakMeters: Double
    let warnings: [TrainerDayWarning]
    let showsStrength: Bool
    var volumeRows: [TrainerVolumeRangeRow] = []
    var suggestedRuns: Int?

    private var weekdays: ClosedRange<Int> { 1...TrainerConstants.weekdayCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            runsCard
            offCard
            longCard
            suggestionCard
        }
    }

    private var runsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(
                value: Binding(get: { preference.runs }, set: { preference = TrainerDaysPlanner.settingRuns(preference, runs: $0) }),
                in: TrainerDaysPlanner.runsRange(preference)
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    DSCardLabel(TrainerDaysText.runsTitle)
                    HStack(spacing: 8) {
                        Text("\(preference.runs)").font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
                        Text(TrainerDaysText.runsDetail(runs: preference.runs, optional: preference.optional))
                            .font(.caption).foregroundStyle(BrandColors.dim)
                    }
                }
            }
            Toggle(isOn: $preference.optional) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(TrainerDaysText.optionalTitle).font(.footnote)
                    Text(TrainerDaysText.optionalHint).font(.caption2).foregroundStyle(BrandColors.dim)
                }
            }
            Toggle(isOn: $outAndBack) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(TrainerDaysText.outAndBackTitle).font(.footnote)
                    Text(TrainerDaysText.outAndBackHint).font(.caption2).foregroundStyle(BrandColors.dim)
                }
            }
            if !volumeRows.isEmpty {
                Divider().overlay(BrandColors.line)
                TrainerVolumeRangeView(
                    rows: volumeRows, current: preference.runs, peakMeters: peakMeters, suggestedRuns: suggestedRuns
                ) { runs in preference = TrainerDaysPlanner.settingRuns(preference, runs: runs) }
            }
        }
        .brandCard()
    }

    private var offCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(TrainerDaysText.offTitle)
            HStack(spacing: TrainerDaysConstants.chipSpacing) {
                ForEach(weekdays, id: \.self) { weekday in
                    chip(weekday, selected: preference.offDays.contains(weekday), color: BrandColors.rest) {
                        preference = TrainerDaysPlanner.togglingOff(preference, weekday: weekday)
                    }
                    .disabled(weekday == preference.longDay)
                }
            }
            Text(TrainerDaysText.offHint).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private var longCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(TrainerDaysText.longTitle)
            HStack(spacing: TrainerDaysConstants.chipSpacing) {
                ForEach(weekdays, id: \.self) { weekday in
                    chip(weekday, selected: preference.longDay == weekday, color: BrandColors.accent) {
                        preference = TrainerDaysPlanner.choosingLong(preference, weekday: weekday)
                    }
                }
            }
        }
        .brandCard()
    }

    private func chip(_ weekday: Int, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(TrainerText.weekdayName(weekday - 1))
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? color : BrandColors.dim)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    selected ? color.opacity(TrainerDaysConstants.offFillOpacity) : BrandColors.track,
                    in: RoundedRectangle(cornerRadius: TrainerDaysConstants.chipCorner, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TrainerDaysConstants.chipCorner, style: .continuous)
                        .stroke(selected ? color.opacity(TrainerDaysConstants.chipBorderOpacity) : BrandColors.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var hardWarnings: [TrainerDayWarning] { warnings.filter { !$0.isSoft } }

    private var suggestionCard: some View {
        let warned = TrainerDaysPlanner.warnedDays(warnings)
        let alternates = TrainerEngine.alternatesQuality(structure)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                DSCardLabel(TrainerDaysText.suggestionTitle)
                Spacer(minLength: 6)
                if hardWarnings.isEmpty {
                    Label(TrainerDaysText.allRules, systemImage: "checkmark")
                        .font(.caption).foregroundStyle(BrandColors.accent)
                } else {
                    Label(TrainerDaysText.warningsCount(hardWarnings.count), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(BrandColors.attention)
                }
            }
            HStack(spacing: TrainerConstants.stripSpacing) {
                ForEach(weekdays, id: \.self) { weekday in
                    VStack(spacing: 4) {
                        dayMenu(weekday, warned: warned.contains(weekday), alternates: alternates)
                        if showsStrength { strengthMenu(weekday) }
                    }
                }
            }
            Text(TrainerDaysText.summary(
                peakMeters: peakMeters, meters: meters.values.reduce(0, +), quality: TrainerEngine.qualityPerWeek(structure), alternates: alternates
            ))
            .font(.caption).foregroundStyle(BrandColors.dim)
            ForEach(warnings, id: \.self) { warning in
                Text(warning.text).font(.caption).foregroundStyle(warning.isSoft ? BrandColors.dim : BrandColors.attention)
            }
            HStack {
                Text(showsStrength ? TrainerText.strengthGridHint : TrainerText.editGridHint)
                    .font(.caption2).foregroundStyle(BrandColors.dim)
                Spacer(minLength: 6)
                if structure != suggested {
                    Button(TrainerDaysText.backToSuggestion) { structure = suggested }
                        .font(.caption.weight(.semibold))
                        .tint(BrandColors.accent)
                }
            }
        }
        .brandCard()
    }

    private func dayMenu(_ weekday: Int, warned: Bool, alternates: Bool) -> some View {
        Menu {
            ForEach(TrainerConstants.editableKinds, id: \.self) { option in
                Button(TrainerText.kindName(option)) { structure[weekday] = option }
            }
        } label: {
            TrainerDayCell(
                weekday: weekday, kind: structure[weekday] ?? .off, meters: meters[weekday] ?? 0, warned: warned, alternates: alternates
            )
        }
    }

    private func strengthMenu(_ weekday: Int) -> some View {
        let current = strength.first { $0.weekday == weekday }
        return Menu {
            Button(TrainerText.strengthNone) { setStrength(nil, on: weekday) }
            ForEach(TrainerConstants.strengthGroups, id: \.self) { group in
                Button(TrainerText.groupName(group)) { setStrength(group, on: weekday) }
            }
        } label: {
            Text(current.map { TrainerText.groupShort($0.group) } ?? "+")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(current == nil ? BrandColors.dim : BrandColors.strength)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    current == nil ? BrandColors.track : BrandColors.strengthGlow,
                    in: RoundedRectangle(cornerRadius: TrainerDaysConstants.cellCorner, style: .continuous)
                )
        }
    }

    private func setStrength(_ group: TrainerStrengthGroup?, on weekday: Int) {
        strength.removeAll { $0.weekday == weekday }
        guard let group else { return }
        strength.append(TrainerStrengthSession(
            weekday: weekday, group: group, legLoad: TrainerConstants.defaultLoad(for: group), name: TrainerText.groupName(group)
        ))
    }
}
