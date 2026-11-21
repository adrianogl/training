import Insights
import SwiftUI
import TrainingCore
import UIKit

struct ClaudeImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let summary: String?
    let results: [ClaudeDayResult]
    let failure: String?
    var planNotice: String?
    let onApply: () -> Void
    @State private var message: String?

    private var validCount: Int { results.filter(\.isValid).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let failure {
                        Text(failure).font(.footnote).foregroundStyle(BrandColors.danger)
                    }
                    if let planNotice, results.contains(where: { $0.errors.contains(.outOfPeriod) }) {
                        Text(planNotice).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.attention)
                    }
                    if let summary {
                        Text("\"\(summary)\"").font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                                if index > 0 { Divider().overlay(BrandColors.line) }
                                row(result).padding(.vertical, 8)
                            }
                        }
                        .brandCard()
                        Button(ClaudeText.apply(validCount)) {
                            onApply()
                            message = ClaudeText.applied
                        }
                        .buttonStyle(.ds(.primary))
                        .disabled(validCount == 0 || message == ClaudeText.applied)
                        if results.contains(where: { !$0.errors.isEmpty }) {
                            Button(ClaudeText.copyErrors) {
                                UIPasteboard.general.string = ClaudeContextBuilder.errorsMessage(results)
                                message = ClaudeText.errorsCopied
                            }
                            .buttonStyle(.ds(.secondary))
                        }
                    }
                    if let message {
                        Text(message).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(ClaudeText.importTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(ClaudeText.close) { dismiss() } }
            }
        }
    }

    private func row(_ result: ClaudeDayResult) -> some View {
        let symbol = !result.errors.isEmpty ? "xmark.circle.fill" : result.warnings.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        let color = !result.errors.isEmpty ? BrandColors.danger : result.warnings.isEmpty ? BrandColors.accent : BrandColors.attention
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(result)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                if let workout = result.workout {
                    Text(String(format: ClaudeText.estimatedFormat, workout.exercises.count, Int(workout.estimatedMinutes.rounded())))
                        .font(.caption).foregroundStyle(BrandColors.dim)
                }
                if result.replacesMFIT, result.isValid {
                    Text(ClaudeText.replacesNote).font(.caption.weight(.semibold)).foregroundStyle(ClaudeConstants.color)
                }
                ForEach(result.errors + result.warnings, id: \.self) { issue in
                    Text(ClaudeText.issue(issue)).font(.caption).foregroundStyle(result.errors.contains(issue) ? BrandColors.danger : BrandColors.attention)
                }
            }
        }
    }

    private func title(_ result: ClaudeDayResult) -> String {
        guard let day = result.day else { return result.rawDay }
        let focus = result.workout.map { TrainerStrengthText.focusName($0.group) } ?? ""
        return "\(TrainerText.weekdayShort(day)) \(TrainerText.dayMonth(day)) · \(focus)"
    }
}
