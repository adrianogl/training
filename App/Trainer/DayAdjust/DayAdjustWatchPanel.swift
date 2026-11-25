import Insights
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct DayAdjustWatchPanel: View {
    let watch: DayAdjustWatch
    let nowEntries: DayAdjustEntries?
    var later: [DayAdjustHourOption] = []
    var isBusy = false
    let send: (DayAdjustEntries) async -> String?

    @State private var selectedHour: Int?
    @State private var isSending = false
    @State private var sendError: String?
    private typealias C = DayAdjustWatchConstants

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s3) {
            if let status = DayAdjustWatchRules.status(watch) {
                Text(status).font(.caption).foregroundStyle(BrandColors.dim).monospacedDigit()
            }
            if let nowEntries, DayAdjustWatchRules.showsNow(watch, now: nowEntries) {
                Button { send(nowEntries) } label: {
                    buttonLabel(String(format: C.nowButtonDeltaFormat, nowEntries.hour, DayAdjustWatchRules.seconds(TrainerDayAdjust.adjust(watch.workout, entries: nowEntries))))
                }
                .buttonStyle(.ds(.secondary))
                .disabled(isSending || isBusy)
            }
            if !later.isEmpty { laterSection }
            if let sendError {
                DSNotice(tone: .attention, text: sendError)
            }
        }
    }

    private var laterSection: some View {
        let selected = later.first { $0.hour == selectedHour } ?? later.first { $0.hour == watch.entries.hour } ?? later[0]
        let onWatch = DayAdjustWatchRules.matchesWatch(selected, watch: watch)
        return VStack(alignment: .leading, spacing: DSSpacing.s2) {
            Text(C.laterTitle).font(.caption).foregroundStyle(BrandColors.dim)
            HStack(spacing: 6) {
                ForEach(later, id: \.hour) { option in
                    chip(option, isSelected: option.hour == selected.hour)
                }
            }
            Button { send(selected.entries) } label: {
                buttonLabel(String(format: C.sendForHourFormat, selected.hour))
            }
            .buttonStyle(.ds(.primary))
            .disabled(onWatch || isSending || isBusy)
            Text(note(selected, onWatch: onWatch)).font(.caption).foregroundStyle(BrandColors.dim).monospacedDigit()
        }
    }

    private func chip(_ option: DayAdjustHourOption, isSelected: Bool) -> some View {
        let onWatch = DayAdjustWatchRules.matchesWatch(option, watch: watch)
        return Button { selectedHour = option.hour } label: {
            VStack(spacing: 1) {
                Text(String(format: onWatch ? C.hourOnWatchFormat : C.hourFormat, option.hour))
                    .font(.caption2).foregroundStyle(onWatch ? BrandColors.accent : BrandColors.dim).lineLimit(1).minimumScaleFactor(0.7)
                if let pace = option.paceLow {
                    Text(WorkoutFormat.clock(pace)).font(BrandFonts.number(16)).foregroundStyle(BrandColors.text)
                }
                Text(String(format: C.extraFormat, option.seconds)).font(.caption2.weight(.semibold)).foregroundStyle(BrandColors.attention)
            }
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.s2)
            .background(isSelected ? BrandColors.accentFill.opacity(0.18) : BrandColors.track, in: RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous).strokeBorder(isSelected ? BrandColors.accentFill : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func note(_ option: DayAdjustHourOption, onWatch: Bool) -> String {
        if onWatch, let sentAt = watch.sentAt {
            return String(format: C.onWatchNoteFormat, DayAdjustWatchRules.time(sentAt))
        }
        let delta = option.seconds - DayAdjustWatchRules.seconds(watch.result)
        return String(format: C.changeNoteFormat, delta > 0 ? "+\(delta)" : "\(delta)")
    }

    private func buttonLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            if isSending { ProgressView().controlSize(.small) }
            Text(isSending ? C.sendingNow : title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func send(_ entries: DayAdjustEntries) {
        isSending = true
        sendError = nil
        Task {
            let error = await send(entries)
            isSending = false
            sendError = error
            if error == nil { selectedHour = nil }
        }
    }
}
