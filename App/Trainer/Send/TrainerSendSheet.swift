import GarminAPI
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
        let items = app.trainer.sendItems(filter, settings: settings)
        let records = store.records()
        let stale = app.trainer.staleSends(filter, items: items, store: store)
        let pending = items.filter { !excluded.contains($0.key) && TrainerSendBuilder.status($0, records: records) != .current }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(TrainerSendText.title, selection: $filter) {
                        ForEach(TrainerSendFilter.allCases) { Text(TrainerSendText.filterName($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if filter != .strength, !settings.runFromTrainer {
                        Text(TrainerSendText.runFromAdvisory).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        DSCardLabel(TrainerSendText.windowLabel).padding(.bottom, 6)
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
                        Text(String(format: TrainerSendText.removedFormat, stale.count)).font(.footnote).foregroundStyle(BrandColors.attention)
                    }
                    Text(app.garminAccount.client == nil ? TrainerSendText.needsLogin : TrainerSendText.onlyApp)
                        .font(.caption).foregroundStyle(BrandColors.dim)
                    Button(buttonTitle(pending.count + stale.count)) {
                        send(pending, stale: stale)
                    }
                    .buttonStyle(.ds(.primary))
                    .disabled(sending || app.trainer.isSendingToGarmin || app.garminAccount.client == nil || pending.count + stale.count == 0)
                    if let message {
                        Text(message).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
                    }
                    settingsCard
                }
                .id(revision)
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(TrainerSendText.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerSendText.close) { dismiss() } }
            }
        }
    }

    private func row(_ item: TrainerSendItem, status: TrainerSendStatus) -> some View {
        let included = !excluded.contains(item.key)
        let color = item.kind == .strength ? BrandColors.strength : BrandColors.accentFill
        return Button {
            if included { excluded.insert(item.key) } else { excluded.remove(item.key) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: included ? "checkmark.square.fill" : "square")
                    .foregroundStyle(included ? color : BrandColors.dim)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(TrainerText.weekdayName(item.day.weekStart.days(until: item.day))) · \(item.title)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                }
                Spacer(minLength: 6)
                Text(TrainerSendText.status(status))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(status == .current ? BrandColors.accent : status == .changed ? BrandColors.attention : BrandColors.fitness)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .current)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(TrainerSendText.runToggle, isOn: Binding(get: { settings.runFromTrainer }, set: { value in
                settings.runFromTrainer = value
                store.save(settings)
            }))
            .tint(BrandColors.accentFill)
            Text(TrainerSendText.autoLabel).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
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
        return count == 0 ? TrainerSendText.upToDate : String(format: TrainerSendText.sendFormat, count)
    }

    private func send(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)]) {
        guard let client = app.garminAccount.client else { return }
        sending = true
        Task {
            guard let result = await app.trainer.sendToGarmin(items, stale: stale, client: client) else {
                sending = false
                return
            }
            var text = String(format: TrainerSendText.resultFormat, result.sent, result.removed)
            if result.failed > 0 { text += String(format: TrainerSendText.failedFormat, result.failed) }
            message = text
            sending = false
            revision += 1
        }
    }
}
