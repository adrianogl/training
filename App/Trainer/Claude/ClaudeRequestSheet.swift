import Insights
import SwiftUI
import TrainingCore
import UIKit

struct ClaudeRequestSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let race: ClaudeRaceTarget?
    @State private var period: ClaudeRequestPeriod
    @State private var extra = ""
    @State private var copied = false

    init(race: ClaudeRaceTarget?) {
        self.race = race
        _period = State(initialValue: race == nil ? .nextWeek : .untilRace)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(ClaudeText.periodLabel).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
                    Picker(ClaudeText.periodLabel, selection: $period) {
                        ForEach(ClaudeRequestPeriod.allCases) { Text(ClaudeText.periodName($0, race: race?.name)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ClaudeText.includesTitle).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
                        ForEach(ClaudeText.includes, id: \.self) { line in
                            Label(line, systemImage: "checkmark").font(.footnote).foregroundStyle(BrandColors.text)
                        }
                    }
                    .brandCard()
                    Text(ClaudeText.extraLabel).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
                    TextField(ClaudeText.extraPlaceholder, text: $extra, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(10)
                        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button(ClaudeText.copy) {
                        UIPasteboard.general.string = ClaudeContextBuilder.text(app.trainer.claudeContextInput(period, race: race), extra: extra)
                        copied = true
                    }
                    .buttonStyle(TrainerPrimaryButtonStyle())
                    if copied {
                        Text(ClaudeText.copied).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(ClaudeText.requestTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(ClaudeText.close) { dismiss() } }
            }
        }
    }
}
