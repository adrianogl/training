import GarminAPI
import MFIT
import SwiftUI
import TrainingCore

struct TrainerSendSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var filter: TrainerSendFilter
    @State private var settings: TrainerSendSettings
    @State private var excluded: Set<String> = []
    @State private var sending = false
    @State private var message: String?
    @State private var revision = 0

    private let store = TrainerSendStore()

    init() {
        let settings = TrainerSendStore().settings()
        _settings = State(initialValue: settings)
        _filter = State(initialValue: settings.runFromTrainer ? .both : .strength)
    }

    var body: some View {
        let isApple = app.watchKind == .appleWatch
        let effective = TrainerSendSettings(runFromTrainer: isApple || settings.runFromTrainer, auto: settings.auto, includesMFIT: !isApple && settings.sendsMFIT)
        let program = StrengthProgramStore().load().program
        let mfitEnd = effective.sendsMFIT && filter != .run ? program.map { MFITSendBuilder.end($0, today: app.trainer.currentDay) } : nil
        let items = app.trainer.sendItems(filter, settings: effective)
        let records = store.records()
        let stale = app.trainer.staleSends(filter, items: items, store: store)
        let pending = items.filter { !excluded.contains($0.key) && TrainerSendBuilder.status($0, records: records) != .current }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrainerSendConstants.rowSpacing) {
                    Picker(TrainerSendText.title, selection: $filter) {
                        ForEach(TrainerSendFilter.allCases) { Text(TrainerSendText.filterName($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if filter != .strength, !effective.runFromTrainer {
                        Text(TrainerSendText.runFromAdvisory).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    section(TrainerSendText.windowLabel(mfitEnd: mfitEnd))
                    VStack(alignment: .leading, spacing: 0) {
                        if items.isEmpty {
                            Text(TrainerSendText.empty).font(.footnote).foregroundStyle(BrandColors.dim).padding(.vertical, 8)
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Divider().overlay(BrandColors.line) }
                            row(item, status: TrainerSendBuilder.status(item, records: records))
                        }
                    }
                    .brandCard()
                    if !stale.isEmpty {
                        Text(TrainerSendText.removed(stale.count)).font(.footnote).foregroundStyle(BrandColors.attention)
                    }
                    Text(isApple ? TrainerSendText.appleOnlyApp : app.garminAccount.client == nil ? TrainerSendText.needsLogin : TrainerSendText.onlyApp)
                        .font(.caption).foregroundStyle(BrandColors.dim)
                    Button(buttonTitle(pending.count + stale.count)) {
                        send(pending, stale: stale)
                    }
                    .buttonStyle(.ds(.primary))
                    .disabled(sending || app.trainer.isSendingToGarmin || (!isApple && app.garminAccount.client == nil) || pending.count + stale.count == 0)
                    if let message {
                        Text(message).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
                    }
                    if app.watchKind != .appleWatch {
                        section(TrainerSendText.runSection)
                        runCard
                        if program != nil {
                            section(TrainerSendText.mfitSection)
                            mfitCard(end: program.map { MFITSendBuilder.end($0, today: app.trainer.currentDay) }, count: items.filter(\.isMFIT).count)
                        }
                        section(TrainerSendText.autoLabel)
                        autoCard
                    }
                }
                .id(revision)
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(isApple ? TrainerSendText.appleTitle : TrainerSendText.title)
            .task {
                guard !isApple, let client = app.garminAccount.client else { return }
                await app.trainer.forgetDeletedOnGarmin(client: client, store: store)
                revision += 1
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerSendText.close) { dismiss() } }
            }
        }
    }

    private func row(_ item: TrainerSendItem, status: TrainerSendStatus) -> some View {
        let included = !excluded.contains(item.key)
        let color = item.isMFIT ? BrandColors.fitness : item.kind == .strength ? BrandColors.strength : BrandColors.accentFill
        return Button {
            if included { excluded.insert(item.key) } else { excluded.remove(item.key) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: included ? "checkmark.square.fill" : "square")
                    .foregroundStyle(included ? color : BrandColors.dim)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("\(TrainerText.weekdayName(item.day.weekStart.days(until: item.day))) · \(item.title)")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        if item.isMFIT { DSChip(text: TrainerSendText.mfitChip, tone: .fitness) }
                    }
                }
                Spacer(minLength: 6)
                Text(status == .current && app.watchKind == .appleWatch ? TrainerSendText.appleStatusCurrent : TrainerSendText.status(status))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(status == .current ? BrandColors.accent : status == .changed ? BrandColors.attention : BrandColors.fitness)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .current)
    }

    private func section(_ title: String) -> some View {
        DSSectionTitle(title)
            .padding(.top, DSSpacing.sectionTop - TrainerSendConstants.rowSpacing)
            .padding(.bottom, DSSpacing.sectionBottom - TrainerSendConstants.rowSpacing)
    }

    private var runCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(TrainerSendText.runToggle, isOn: Binding(get: { settings.runFromTrainer }, set: { value in
                settings.runFromTrainer = value
                store.save(settings)
            }))
            .tint(BrandColors.accentFill)
            Text(TrainerSendText.runIgnoresAdvisory).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private func mfitCard(end: Day?, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { settings.sendsMFIT }, set: { value in
                settings.includesMFIT = value
                store.save(settings)
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TrainerSendText.mfitToggle)
                    Text(settings.sendsMFIT ? end.map { TrainerSendText.mfitCaption(end: $0, count: count) } ?? TrainerSendText.mfitOffCaption : TrainerSendText.mfitOffCaption)
                        .font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            .tint(BrandColors.accentFill)
            Text(TrainerSendText.mfitHint).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private var autoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(TrainerSendText.autoLabel, selection: Binding(get: { settings.auto }, set: { value in
                settings.auto = value
                store.save(settings)
            })) {
                Text(TrainerSendText.autoName(nil)).tag(TrainerSendFilter?.none)
                ForEach(TrainerSendFilter.allCases) { Text(TrainerSendText.autoName($0)).tag(TrainerSendFilter?.some($0)) }
            }
            .pickerStyle(.segmented)
            Text(TrainerSendText.autoHint).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private func buttonTitle(_ count: Int) -> String {
        if sending { return TrainerSendText.sending }
        let done = app.watchKind == .appleWatch ? TrainerSendText.appleUpToDate : TrainerSendText.upToDate
        return count == 0 ? done : TrainerSendText.sendTitle(count)
    }

    private func send(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)]) {
        let client = app.garminAccount.client
        guard app.watchKind == .appleWatch || client != nil else { return }
        sending = true
        Task {
            let outcome: TrainerSendResult?
            if app.watchKind == .appleWatch {
                outcome = await app.trainer.sendToAppleWatch(items, stale: stale)
            } else if let client {
                outcome = await app.trainer.sendToGarmin(items, stale: stale, client: client)
            } else {
                outcome = nil
            }
            guard let result = outcome else {
                sending = false
                return
            }
            var text = String(format: TrainerSendText.resultFormat, result.sent, result.removed)
            if result.failed > 0 {
                text += result.firstError.map { String(format: TrainerSendText.failedReasonFormat, result.failed, $0) }
                    ?? String(format: TrainerSendText.failedFormat, result.failed)
            }
            message = text
            sending = false
            revision += 1
        }
    }
}
